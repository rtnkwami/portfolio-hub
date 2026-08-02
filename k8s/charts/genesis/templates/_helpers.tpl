{{- define "controller.nodeSelector" -}}
{{- with .Values.controllers.nodePlacement.nodeSelector -}}
nodeSelector:
  {{- toYaml . | nindent 2}}
{{- end -}}
{{- end -}}

{{- define "controller.tolerations" -}}
{{- with .Values.controllers.nodePlacement.tolerations -}}
tolerations:
  {{- toYaml . | nindent 2 }}
{{- end -}}
{{- end -}}
