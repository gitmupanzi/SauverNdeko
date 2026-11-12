from django.urls import re_path

from apps.support.process_workbooks import (
    SupportModelBatchView, SupportModelCSVView, SupportModelExcelPreviewView,
    SupportModelExcelView, SupportModelTemplateView,
)
from apps.support.processes import (
    SupportProcessMonitoringView, SupportProcessRunView, SupportProcessesView,
)

urlpatterns = [
    re_path(r'^processus/suivi/?$', SupportProcessMonitoringView.as_view()),
    re_path(r'^processus/modele\.xlsx/?$', SupportModelTemplateView.as_view()),
    re_path(r'^processus/import\.xlsx/?$', SupportModelExcelPreviewView.as_view()),
    re_path(r'^processus/lot/?$', SupportModelBatchView.as_view()),
    re_path(r'^processus/export\.xlsx/?$', SupportModelExcelView.as_view()),
    re_path(r'^processus/export\.csv/?$', SupportModelCSVView.as_view()),
    re_path(r'^processus(?:/(?P<pk>[0-9]+))?/?$', SupportProcessesView.as_view()),
    re_path(r'^tickets/(?P<pk>[0-9]+)/parcours/?$', SupportProcessRunView.as_view()),
]
