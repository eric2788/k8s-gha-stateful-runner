{{- define "actions-runner.image" }}
{{- $version := $.Values.version -}}
{{- $image := $.Values.image -}}
{{- printf "%s:%s" $image $version -}}
{{- end }}


{{- define "actions-runner.fullname" -}}
{{- $name := default $.Chart.Name $.Values.runner.name -}}
{{- if not $.Values.fullnameOverride -}}
{{- printf "%s-%s" $.Release.Name $name -}}
{{- else -}}
{{- $.Values.fullnameOverride -}}
{{- end -}}
{{- end -}}

{{- define "actions-runner.name" -}}
{{- $name := default $.Chart.Name $.Values.runner.name -}}
{{- printf "%s" $name -}}
{{- end -}}

{{- define "actions-runner.optionalNamespace" -}}
{{- if $.Values.includeNamespace }}
  namespace: {{ default $.Release.Namespace $.Values.namespaceOverride }}
{{- end }}
{{- end -}}

{{- define "actions-runner.secretName" -}}
{{- if not $.Values.runner.secret -}}
{{- include "actions-runner.fullname" $ }}-secret
{{- else -}}
{{- $.Values.runner.secret -}}
{{- end -}}
{{- end -}}

{{- define "actions-runner.serviceAccountName" -}}
{{- if $.Values.serviceAccount.name -}}
{{- $.Values.serviceAccount.name -}}
{{- else if $.Values.serviceAccount.create -}}
{{- include "actions-runner.fullname" $ -}}
{{- else -}}
{{- "default" -}}
{{- end -}}
{{- end -}}

{{- define "actions-runner.labels" -}}
{{- $labels := dict
    "app.kubernetes.io/name" $.Chart.Name
    "app.kubernetes.io/instance" $.Release.Name
    "app.kubernetes.io/version" $.Chart.AppVersion
    "app.kubernetes.io/part-of" $.Chart.Name
    "app.kubernetes.io/component" "runner"
    "app.kubernetes.io/managed-by" "Helm" -}}
{{- $labels | toYaml -}}
{{- end -}}

{{- define "actions-runner.selectorLabels" -}}
{{- $labels := dict
    "app.kubernetes.io/name" ( include "actions-runner.name" $ )
    "app.kubernetes.io/instance" $.Release.Name -}}
{{- $labels | toYaml -}}
{{- end -}}

{{- define "actions-runner.workspaceMountSubPath" -}}
{{- if and $.Values.workspace.enabled $.Values.workspace.subPathExpr -}}
subPathExpr: {{ $.Values.workspace.subPathExpr | quote }}
{{- else if and $.Values.workspace.enabled $.Values.workspace.subPath -}}
subPath: {{ $.Values.workspace.subPath | quote }}
{{- end -}}
{{- end -}}
