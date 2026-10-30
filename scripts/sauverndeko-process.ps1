# Identite des processus sans elevation. Les lectures restent separees de
# l'arret minimal autorise, qui exige une verification native sur le meme handle.
# CIM reste prioritaire. L'API native sert seulement quand Windows masque ses
# champs CommandLine/CreationDate alors que QUERY_LIMITED_INFORMATION est permis.
function Initialize-SauverNdekoProcessReader {
 if ('SauverNdeko.NativeProcessReaderV1' -as [type]) { return }
 Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
namespace SauverNdeko {
 public sealed class ProcessIdentityV1 {
  public int ProcessId { get; set; }
  public DateTime CreationDate { get; set; }
  public string CommandLine { get; set; }
  public string ExecutablePath { get; set; }
 }
 public static class NativeProcessReaderV1 {
  [DllImport("kernel32.dll", SetLastError=true)] static extern IntPtr OpenProcess(uint access,bool inherit,int id);
  [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr handle);
  [DllImport("kernel32.dll", SetLastError=true)] static extern bool GetProcessTimes(IntPtr handle,out long creation,out long exit,out long kernel,out long user);
  [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)] static extern bool QueryFullProcessImageNameW(IntPtr handle,uint flags,StringBuilder path,ref int length);
  [DllImport("kernel32.dll", SetLastError=true)] static extern bool TerminateProcess(IntPtr handle,uint exitCode);
  [DllImport("kernel32.dll", SetLastError=true)] static extern bool GetExitCodeProcess(IntPtr handle,out uint exitCode);
  [DllImport("ntdll.dll")] static extern int NtQueryInformationProcess(IntPtr handle,int type,IntPtr buffer,int length,out int needed);
  [DllImport("shell32.dll", CharSet=CharSet.Unicode, SetLastError=true)] static extern IntPtr CommandLineToArgvW(string command,out int count);
  [DllImport("kernel32.dll")] static extern IntPtr LocalFree(IntPtr memory);
  public static ProcessIdentityV1 Read(int id) {
   if(id<=0)return null;
   IntPtr handle=OpenProcess(0x1000,false,id);
   if(handle==IntPtr.Zero)return null;
   try { return ReadHandle(handle,id); } finally {CloseHandle(handle);}
  }
  static ProcessIdentityV1 ReadHandle(IntPtr handle,int id) {
   IntPtr buffer=IntPtr.Zero;
   try {
    long created,exited,kernel,user;
    if(!GetProcessTimes(handle,out created,out exited,out kernel,out user))return null;
    int needed;NtQueryInformationProcess(handle,60,IntPtr.Zero,0,out needed);
    if(needed<16||needed>1048576)return null;
    int allocated=needed;buffer=Marshal.AllocHGlobal(allocated);
    if(NtQueryInformationProcess(handle,60,buffer,allocated,out needed)!=0)return null;
    int bytes=(ushort)Marshal.ReadInt16(buffer);
    IntPtr text=Marshal.ReadIntPtr(buffer,IntPtr.Size==8?8:4);
    long offset=text.ToInt64()-buffer.ToInt64();
    if(bytes==0||(bytes%2)!=0||offset<0||offset+bytes>allocated)return null;
    string command=Marshal.PtrToStringUni(text,bytes/2);
    if(String.IsNullOrWhiteSpace(command))return null;
    var image=new StringBuilder(32768);int imageLength=image.Capacity;
    string executable=QueryFullProcessImageNameW(handle,0,image,ref imageLength)?image.ToString():null;
    return new ProcessIdentityV1 {ProcessId=id,CreationDate=DateTime.FromFileTimeUtc(created),CommandLine=command,ExecutablePath=executable};
   } finally {
    if(buffer!=IntPtr.Zero)Marshal.FreeHGlobal(buffer);
   }
  }
  public static string TerminateVerified(int id,long expectedTicks,string expectedCommand,string expectedImage) {
   if(id<=0||expectedTicks<=0||String.IsNullOrWhiteSpace(expectedCommand)||String.IsNullOrWhiteSpace(expectedImage))return "Metadonnees de terminaison incompletes.";
   // QUERY_LIMITED_INFORMATION | TERMINATE : aucun ALL_ACCESS ni privilege ajoute.
   IntPtr handle=OpenProcess(0x1001,false,id);
   if(handle==IntPtr.Zero)return "Ouverture minimale refusee (Windows "+Marshal.GetLastWin32Error()+").";
   try {
    ProcessIdentityV1 observed=ReadHandle(handle,id);
    if(observed==null||observed.CreationDate.Ticks!=expectedTicks||!String.Equals(observed.CommandLine,expectedCommand,StringComparison.Ordinal)||!String.Equals(observed.ExecutablePath,expectedImage,StringComparison.OrdinalIgnoreCase))return "Identite native devenue differente ou inaccessible ; terminaison refusee.";
    if(!TerminateProcess(handle,0))return "Terminaison minimale refusee (Windows "+Marshal.GetLastWin32Error()+").";
    for(int attempt=0;attempt<80;attempt++) {
     uint exitCode;if(GetExitCodeProcess(handle,out exitCode)&&exitCode!=259)return null;
     System.Threading.Thread.Sleep(25);
    }
    return "Fin du processus non confirmee ; suivi conserve.";
   } finally {CloseHandle(handle);}
  }
  public static string[] Arguments(string command) {
   if(String.IsNullOrWhiteSpace(command))return new string[0];
   int count;IntPtr arguments=CommandLineToArgvW(command,out count);
   if(arguments==IntPtr.Zero)return new string[0];
   try {
    if(count<1||count>1024)return new string[0];
    string[] result=new string[count];
    for(int i=0;i<count;i++)result[i]=Marshal.PtrToStringUni(Marshal.ReadIntPtr(arguments,i*IntPtr.Size));
    return result;
   } finally {LocalFree(arguments);}
  }
 }
}
'@
}

function Get-SauverNdekoNativeProcessInfo([int]$ProcessId) {
 try {
  Initialize-SauverNdekoProcessReader
  return [SauverNdeko.NativeProcessReaderV1]::Read($ProcessId)
 } catch { return $null }
}

function Get-SauverNdekoProcessInfo([int]$ProcessId) {
 $Information=$null
 try {$Information=Get-CimInstance Win32_Process -Filter "ProcessId=$ProcessId" -ErrorAction SilentlyContinue} catch {}
 if ($null -ne $Information -and $null -ne $Information.CreationDate -and -not [string]::IsNullOrWhiteSpace([string]$Information.CommandLine)) {return $Information}
 $Native=Get-SauverNdekoNativeProcessInfo $ProcessId
 if ($null -ne $Native) {return $Native}
 return $Information
}

function Test-SauverNdekoCreationDate($Actual,$Expected) {
 try {
  if ($null -eq $Actual -or $null -eq $Expected -or [string]::IsNullOrWhiteSpace([string]$Expected)) {return $false}
  [long]$ActualTicks=([datetime]$Actual).ToUniversalTime().Ticks
  [long]$ExpectedTicks=([datetime]$Expected).ToUniversalTime().Ticks
  # Win32_Process/DMTF conserve des microsecondes ; GetProcessTimes des 100 ns.
  # Comparer exactement a la precision de la source commune, sans flottants.
  return (($ActualTicks-($ActualTicks%10)) -eq ($ExpectedTicks-($ExpectedTicks%10)))
 } catch {return $false}
}

function Test-SauverNdekoConsoleHelper($Observed,$Snapshot) {
 try {
  if ($null -eq $Observed -or $null -eq $Snapshot -or [int]$Snapshot.ProcessId -le 0) {return $false}
  # Le nom annonce par CIM ne suffit jamais : la date et le vrai executable
  # sont relus sur un meme handle natif, sans demander le droit de terminaison.
  $Native=Get-SauverNdekoNativeProcessInfo ([int]$Snapshot.ProcessId)
  if ($null -eq $Native -or $Native.ProcessId -ne $Snapshot.ProcessId) {return $false}
  if (-not (Test-SauverNdekoCreationDate $Native.CreationDate $Snapshot.CreationDate) -or -not (Test-SauverNdekoCreationDate $Native.CreationDate $Observed.CreationDate)) {return $false}
  $WindowsRoot=[Environment]::GetFolderPath([Environment+SpecialFolder]::Windows)
  if ([string]::IsNullOrWhiteSpace($WindowsRoot) -or [string]::IsNullOrWhiteSpace([string]$Native.ExecutablePath)) {return $false}
  $Executable=[IO.Path]::GetFullPath([string]$Native.ExecutablePath)
  $SystemDirectory=Join-Path $WindowsRoot 'System32'
  $Accepted=@((Join-Path $SystemDirectory 'conhost.exe'),(Join-Path $SystemDirectory 'OpenConsole.exe'))
  if (-not @($Accepted | Where-Object {[string]::Equals($_,$Executable,[StringComparison]::OrdinalIgnoreCase)}).Count) {return $false}
  Initialize-SauverNdekoProcessReader
  $Arguments=@([SauverNdeko.NativeProcessReaderV1]::Arguments([string]$Native.CommandLine))
  if (-not $Arguments.Count) {return $false}
  $CommandExecutable=$Arguments[0]
  # Windows peut lancer conhost avec le prefixe natif \??\.
  if ($CommandExecutable.StartsWith('\??\') -or $CommandExecutable.StartsWith('\\?\')) {$CommandExecutable=$CommandExecutable.Substring(4)}
  return [string]::Equals([IO.Path]::GetFullPath($CommandExecutable),$Executable,[StringComparison]::OrdinalIgnoreCase)
 } catch {return $false}
}

function Invoke-SauverNdekoNativeTermination([int]$ProcessId,$Expected) {
 Initialize-SauverNdekoProcessReader
 $Failure=[SauverNdeko.NativeProcessReaderV1]::TerminateVerified($ProcessId,([datetime]$Expected.CreationDate).ToUniversalTime().Ticks,[string]$Expected.CommandLine,[string]$Expected.ExecutablePath)
 if (-not [string]::IsNullOrWhiteSpace($Failure)) {throw $Failure}
}

function Stop-SauverNdekoVerifiedProcess([int]$ProcessId,$Expected) {
 if ($ProcessId -le 0 -or $null -eq $Expected -or $null -eq $Expected.CreationDate -or [string]::IsNullOrWhiteSpace([string]$Expected.CommandLine)) {throw 'Metadonnees de processus incompletes ; arret refuse.'}
 try {$null=([datetime]$Expected.CreationDate).ToUniversalTime()} catch {throw 'Date de processus invalide ; arret refuse.'}
 try {Stop-Process -Id $ProcessId -Force -ErrorAction Stop;return}
 catch {
  $AccessDenied=$_.CategoryInfo.Category -eq [Management.Automation.ErrorCategory]::PermissionDenied -or $_.Exception -is [UnauthorizedAccessException] -or ($_.Exception -is [ComponentModel.Win32Exception] -and $_.Exception.NativeErrorCode -eq 5)
  $Cause=$_.Exception
  for ($Depth=0;$Depth -lt 8 -and $null -ne $Cause;$Depth++) {
   if ($Cause -is [UnauthorizedAccessException] -or ($Cause -is [ComponentModel.Win32Exception] -and $Cause.NativeErrorCode -eq 5)) {$AccessDenied=$true;break}
   $Cause=$Cause.InnerException
  }
  if (-not $AccessDenied) {throw}
  $Native=Get-SauverNdekoNativeProcessInfo $ProcessId
  if ($null -eq $Native -or $Native.ProcessId -ne $ProcessId -or -not (Test-SauverNdekoCreationDate $Native.CreationDate $Expected.CreationDate) -or [string]::IsNullOrWhiteSpace([string]$Expected.CommandLine) -or -not [string]::Equals([string]$Native.CommandLine,[string]$Expected.CommandLine,[StringComparison]::Ordinal) -or [string]::IsNullOrWhiteSpace([string]$Native.ExecutablePath)) {throw 'Identite incomplete ou differente apres le refus Windows ; arret refuse et suivi conserve.'}
  $ExpectedImage=$Expected.PSObject.Properties['ExecutablePath']
  if ($null -ne $ExpectedImage -and -not [string]::IsNullOrWhiteSpace([string]$ExpectedImage.Value) -and -not [string]::Equals([string]$ExpectedImage.Value,[string]$Native.ExecutablePath,[StringComparison]::OrdinalIgnoreCase)) {throw 'Executable devenu different apres le refus Windows ; arret refuse et suivi conserve.'}
  # Le second controle se fait sur le handle de terminaison lui-meme. Le PID
  # ne peut donc pas etre recycle entre la derniere verification et l'action.
  Invoke-SauverNdekoNativeTermination $ProcessId $Native
 }
}

function Test-SauverNdekoServiceCommand([string]$Command,$Record,[string]$ExpectedScript,[string]$ExpectedProject) {
 try {
  if ([string]::IsNullOrWhiteSpace($Command) -or $null -eq $Record -or [string]::IsNullOrWhiteSpace([string]$Record.instance)) {return $false}
  Initialize-SauverNdekoProcessReader
  $Arguments=@([SauverNdeko.NativeProcessReaderV1]::Arguments($Command))
  if ($Arguments.Count -lt 9) {return $false}
  if ([IO.Path]::GetFileNameWithoutExtension($Arguments[0]) -ne 'powershell') {return $false}
  $Required=@{'-File'=$ExpectedScript;'-ProjectRoot'=$ExpectedProject;'-Service'=[string]$Record.name;'-Instance'=[string]$Record.instance}
  foreach ($Key in $Required.Keys) {
   $Positions=@(for($Index=1;$Index -lt $Arguments.Count;$Index++) {if ([string]::Equals($Arguments[$Index],$Key,[StringComparison]::OrdinalIgnoreCase)) {$Index}})
   if ($Positions.Count -ne 1 -or $Positions[0]+1 -ge $Arguments.Count) {return $false}
   $Value=$Arguments[$Positions[0]+1]
   $Comparison=if ($Key -eq '-Instance') {[StringComparison]::Ordinal} else {[StringComparison]::OrdinalIgnoreCase}
   if (-not [string]::Equals($Value,[string]$Required[$Key],$Comparison)) {return $false}
  }
  return $Record.name -in @('backend','frontend')
 } catch {return $false}
}
