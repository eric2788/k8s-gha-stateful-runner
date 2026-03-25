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
{{- printf "subPathExpr: %s" ($.Values.workspace.subPathExpr | quote) | nindent 14 -}}
{{- else if and $.Values.workspace.enabled $.Values.workspace.subPath -}}
{{- printf "subPath: %s" ($.Values.workspace.subPath | quote) | nindent 14 -}}
{{- end -}}
{{- end -}}

{{- define "actions-runner.workspaceVolumeSource" -}}
{{- if not $.Values.workspace.enabled }}
- name: runner-work
  emptyDir: {}
{{- else if $.Values.workspace.existingClaim }}
- name: runner-work
  persistentVolumeClaim:
    claimName: {{ $.Values.workspace.existingClaim }}
{{- end }}
{{- end -}}

{{- define "actions-runner.podVolumes" -}}
{{- $chunks := list -}}
{{- $workspaceVolume := include "actions-runner.workspaceVolumeSource" $ | trim -}}
{{- if $workspaceVolume -}}
{{- $chunks = append $chunks $workspaceVolume -}}
{{- end -}}
{{- if and $.Values.dind.enable (not $.Values.dind.cachePersistence) -}}
{{- $chunks = append $chunks "- name: docker-storage\n  emptyDir: {}" -}}
{{- end -}}
{{- with $.Values.extraVolumes -}}
{{- $chunks = append $chunks (toYaml . | trim) -}}
{{- end -}}
{{- if $chunks -}}
{{ join "\n" $chunks }}
{{- end -}}
{{- end -}}

{{- define "actions-runner.dindPrunePreStopScript" -}}
# Bound prune runtime so runner drain still has termination budget.
PRUNE_TIMEOUT={{ $.Values.dind.pruneTimeoutSeconds }}
if [ "$PRUNE_TIMEOUT" -eq 0 ]; then
  docker system prune -f || true
  exit 0
fi

docker system prune -f &
PRUNE_PID=$!
START_TS=$(date +%s)

while kill -0 "$PRUNE_PID" 2>/dev/null; do
  NOW_TS=$(date +%s)
  ELAPSED=$((NOW_TS - START_TS))
  if [ "$ELAPSED" -ge "$PRUNE_TIMEOUT" ]; then
    echo "DinD preStop prune timed out after ${PRUNE_TIMEOUT}s; continuing termination."
    kill -TERM "$PRUNE_PID" 2>/dev/null || true
    sleep 2
    kill -KILL "$PRUNE_PID" 2>/dev/null || true
    break
  fi
  sleep 2
done

wait "$PRUNE_PID" 2>/dev/null || true
{{- end -}}
