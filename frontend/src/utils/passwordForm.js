export function passwordErrors(values,policy) {
  const errors={},length=value=>Array.from(value).length;
  if(!values.currentPassword)errors.currentPassword="Renseignez votre mot de passe actuel.";
  else if(length(values.currentPassword)>policy.currentPasswordMaxLength)errors.currentPassword="Le mot de passe actuel est trop long.";
  if(!values.newPassword.trim())errors.newPassword="Renseignez un nouveau mot de passe.";
  else if(length(values.newPassword)<policy.minLength)errors.newPassword="Utilisez au moins "+policy.minLength+" caractères.";
  else if(length(values.newPassword)>policy.maxLength)errors.newPassword="Utilisez au maximum "+policy.maxLength+" caractères.";
  else if(values.newPassword===values.currentPassword)errors.newPassword="Choisissez un mot de passe différent du mot de passe actuel.";
  if(!values.confirmPassword)errors.confirmPassword="Confirmez le nouveau mot de passe.";
  else if(values.confirmPassword!==values.newPassword)errors.confirmPassword="Les nouveaux mots de passe ne correspondent pas.";
  return errors;
}
