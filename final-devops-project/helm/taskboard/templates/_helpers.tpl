{{- define "taskboard.labels" -}}
app.kubernetes.io/part-of: taskboard
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
environment: {{ .Values.environment }}
{{- end }}

{{- define "taskboard.dbSecret" -}}
{{- if .Values.postgres.existingSecret }}{{ .Values.postgres.existingSecret }}{{ else }}{{ .Release.Name }}-db{{ end }}
{{- end }}

{{- define "taskboard.podSecurity" -}}
runAsNonRoot: true
seccompProfile:
  type: RuntimeDefault
{{- end }}

{{- define "taskboard.containerSecurity" -}}
allowPrivilegeEscalation: false
readOnlyRootFilesystem: true
capabilities:
  drop: ["ALL"]
{{- end }}
