{{/*
workload.validate — every cross-field rule in one place. Fails the render with a message that
names the offending values. Rules that concern a single field live in values.schema.json.
*/}}
{{- define "workload.validate" -}}
{{- $v := .Values -}}

{{- /* One workload kind at most. */ -}}
{{- $kinds := list -}}
{{- if $v.deployment.enabled }}{{- $kinds = append $kinds "deployment" }}{{- end -}}
{{- if $v.statefulset.enabled }}{{- $kinds = append $kinds "statefulset" }}{{- end -}}
{{- if $v.job.enabled }}{{- $kinds = append $kinds "job" }}{{- end -}}
{{- if $v.cronjob.enabled }}{{- $kinds = append $kinds "cronjob" }}{{- end -}}
{{- if gt (len $kinds) 1 }}
{{- fail (printf "deployment, statefulset, job and cronjob are mutually exclusive, but %s are all enabled. Choose one workload kind per release." (join ", " $kinds)) }}
{{- end -}}

{{- if and $v.cronjob.enabled (not $v.cronjob.schedule) }}
{{- fail "cronjob.schedule is required when cronjob.enabled is true" }}
{{- end -}}

{{- /* Service: every name in service.ports must exist in ports. The helper fails on a stranger. */ -}}
{{- $portNames := list -}}
{{- range $v.ports }}{{- $portNames = append $portNames .name }}{{- end -}}
{{- $_ := include "workload.servicePorts" . -}}

{{- /* Ingress needs a Service to route to, with the port it names. */ -}}
{{- if $v.ingress.enabled }}
{{- if not $v.service.enabled }}
{{- fail "ingress.enabled requires service.enabled" }}
{{- end }}
{{- if not $v.ports }}
{{- fail "ingress.enabled requires at least one entry in ports" }}
{{- end }}
{{- if not (has $v.ingress.port $portNames) }}
{{- fail (printf "ingress.port %q is not a name in ports (known: %s)" $v.ingress.port (join ", " $portNames)) }}
{{- end }}
{{- $exposed := $v.service.ports | default $portNames }}
{{- if not (has $v.ingress.port $exposed) }}
{{- fail (printf "ingress.port %q is not exposed by the Service (exposed: %s)" $v.ingress.port (join ", " $exposed)) }}
{{- end }}
{{- end -}}

{{- /* HPA and PDB only make sense for a replicated workload. */ -}}
{{- $replicated := or $v.deployment.enabled $v.statefulset.enabled -}}
{{- if and $v.autoscaling.enabled (not $replicated) }}
{{- fail "autoscaling.enabled requires deployment.enabled or statefulset.enabled" }}
{{- end -}}
{{- if and $v.autoscaling.enabled (not (include "workload.isSet" $v.autoscaling.targetCPUUtilizationPercentage)) (not (include "workload.isSet" $v.autoscaling.targetMemoryUtilizationPercentage)) }}
{{- fail "autoscaling.enabled requires targetCPUUtilizationPercentage or targetMemoryUtilizationPercentage" }}
{{- end -}}
{{- if and $v.autoscaling.enabled (gt (int $v.autoscaling.minReplicas) (int $v.autoscaling.maxReplicas)) }}
{{- fail (printf "autoscaling.minReplicas (%d) must not exceed autoscaling.maxReplicas (%d)" (int $v.autoscaling.minReplicas) (int $v.autoscaling.maxReplicas)) }}
{{- end -}}
{{- if and $v.podDisruptionBudget.enabled (not $replicated) }}
{{- fail "podDisruptionBudget.enabled requires deployment.enabled or statefulset.enabled" }}
{{- end -}}
{{- if and $v.podDisruptionBudget.enabled (include "workload.isSet" $v.podDisruptionBudget.minAvailable) (include "workload.isSet" $v.podDisruptionBudget.maxUnavailable) }}
{{- fail "podDisruptionBudget: set minAvailable or maxUnavailable, not both" }}
{{- end -}}
{{- if and $v.podDisruptionBudget.enabled (not (include "workload.isSet" $v.podDisruptionBudget.minAvailable)) (not (include "workload.isSet" $v.podDisruptionBudget.maxUnavailable)) }}
{{- fail "podDisruptionBudget.enabled requires minAvailable or maxUnavailable" }}
{{- end -}}

{{- /* A NetworkPolicy ignores rules for a direction that is not in policyTypes. */ -}}
{{- if $v.networkPolicy.enabled }}
{{- $types := $v.networkPolicy.policyTypes | default list }}
{{- if and $types $v.networkPolicy.egress (not (has "Egress" $types)) }}
{{- fail "networkPolicy.egress has rules but networkPolicy.policyTypes does not include Egress, so they would be ignored" }}
{{- end }}
{{- if and $types $v.networkPolicy.ingress (not (has "Ingress" $types)) }}
{{- fail "networkPolicy.ingress has rules but networkPolicy.policyTypes does not include Ingress, so they would be ignored" }}
{{- end }}
{{- end -}}

{{- /* StatefulSet volume claim templates only apply to a StatefulSet. */ -}}
{{- if and $v.statefulset.volumeClaimTemplates (not $v.statefulset.enabled) }}
{{- fail "statefulset.volumeClaimTemplates requires statefulset.enabled" }}
{{- end -}}

{{- /* Two sources must not claim the same volume name. */ -}}
{{- $volumeNames := list -}}
{{- range $name, $cm := $v.configMaps }}{{- if and $cm.enabled $cm.mountPath }}{{- $volumeNames = append $volumeNames $name }}{{- end }}{{- end -}}
{{- range $name, $es := $v.externalSecrets }}{{- if and $es.enabled $es.mountPath }}{{- $volumeNames = append $volumeNames $name }}{{- end }}{{- end -}}
{{- range $name, $pvc := $v.persistentVolumeClaims }}{{- if $pvc.mountPath }}{{- $volumeNames = append $volumeNames $name }}{{- end }}{{- end -}}
{{- range $name, $vct := $v.statefulset.volumeClaimTemplates }}{{- if $vct.mountPath }}{{- $volumeNames = append $volumeNames $name }}{{- end }}{{- end -}}
{{- if ne (len $volumeNames) (len (uniq $volumeNames)) }}
{{- fail (printf "configMaps, externalSecrets, persistentVolumeClaims and statefulset.volumeClaimTemplates share one volume namespace, but a name is used twice among: %s" (join ", " $volumeNames)) }}
{{- end -}}
{{- end }}
