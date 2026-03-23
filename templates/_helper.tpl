{{- define "actions-runner.image" }}
{{- $version := $.Values.version -}}
{{- $image := $.Values.image -}}
{{- printf "%s:%s" $image $version -}}
{{- end }}


{{- define "actions-runner.fullname" -}}
{{- $name := default .Chart.Name .Values.runner.name -}}
{{- if not $.Values.runner.fullnameOverride -}}
{{- printf "%s-%s" .Release.Name $name -}}
{{- else -}}
{{- $.Values.runner.fullnameOverride -}}
{{- end -}}
{{- end -}}

{{- define "actions-runner.name" -}}
{{- $name := default .Chart.Name .Values.runner.name -}}
{{- printf "%s" $name -}}
{{- end -}}

{{- define "actions-runner.secretName" -}}
{{- if not $.Values.runner.secret -}}
{{- include "actions-runner.fullname" $ }}-secret
{{- else -}}
{{- $.Values.runner.secret -}}
{{- end -}}
{{- end -}}

{{- define "actions-runner.labels" -}}
{{- $labels := dict
    "app.kubernetes.io/name" .Chart.Name
    "app.kubernetes.io/instance" .Release.Name
    "app.kubernetes.io/version" .Chart.AppVersion
    "app.kubernetes.io/part-of" .Chart.Name
    "app.kubernetes.io/managed-by" "Helm" -}}
{{- $labels | toYaml -}}
{{- end -}}

{{- define "actions-runner.selectorLabels" -}}
{{- $labels := dict
    "app.kubernetes.io/name" ( include "actions-runner.name" $ )
    "app.kubernetes.io/instance" .Release.Name -}}
{{- $labels | toYaml -}}
{{- end -}}