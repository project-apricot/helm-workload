{{/*
workload.name — app name used in labels (app.kubernetes.io/name) and as the container name.
Defaults to the release name. Uses .Values.nameOverride when set. Truncated to 63 characters.
*/}}
{{- define "workload.name" -}}
{{- if .Values.nameOverride }}
{{- .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
workload.fullname — name of every generated object. Defaults to the release name, so a Service
is named after the app, which is what service discovery relies on.

Priority: fullnameOverride, then <release>-<nameOverride>, then <release>. Truncated to 63 characters.
*/}}
{{- define "workload.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else if .Values.nameOverride }}
{{- printf "%s-%s" .Release.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
workload.chart — value of the helm.sh/chart label: <chart-name>-<chart-version>.
*/}}
{{- define "workload.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
workload.selectorLabels — the label subset used in selectors.
IMPORTANT: never change these after a first deploy. Kubernetes rejects selector changes.
*/}}
{{- define "workload.selectorLabels" -}}
app.kubernetes.io/name: {{ include "workload.name" . | quote }}
app.kubernetes.io/instance: {{ .Release.Name | quote }}
{{- end }}

{{/*
workload.labels — labels for every generated object. .Values.commonLabels wins on a clash.
*/}}
{{- define "workload.labels" -}}
{{- $base := dict "helm.sh/chart" (include "workload.chart" .) "app.kubernetes.io/name" (include "workload.name" .) "app.kubernetes.io/instance" .Release.Name "app.kubernetes.io/managed-by" .Release.Service -}}
{{- toYaml (merge (dict) (.Values.commonLabels | default dict) $base) }}
{{- end }}

{{/*
workload.podLabels — labels for the pod template: .Values.commonLabels, then .Values.podLabels, then the
selector labels, which always win so a pod keeps matching its own selector. It carries no chart version,
so bumping the chart alone does not restart pods.
*/}}
{{- define "workload.podLabels" -}}
{{- $selector := dict "app.kubernetes.io/name" (include "workload.name" .) "app.kubernetes.io/instance" .Release.Name -}}
{{- $out := dict -}}
{{- range $k, $v := (.Values.commonLabels | default dict) }}{{- $_ := set $out $k $v }}{{- end -}}
{{- range $k, $v := (.Values.podLabels | default dict) }}{{- $_ := set $out $k $v }}{{- end -}}
{{- range $k, $v := $selector }}{{- $_ := set $out $k $v }}{{- end -}}
{{- toYaml $out }}
{{- end }}

{{/*
workload.annotations — annotations for an object's metadata. Renders nothing when there are none.

Takes a dict:
  ctx        the root context
  extra      annotations set by the user for this object (highest precedence, even an empty value)
  provenance true to merge the provenance annotations (workload objects only)
  defaults   optional dict of generated annotations (lowest precedence)

Precedence, lowest to highest: defaults, provenance, commonAnnotations, extra.

Usage:
  {{- with include "workload.annotations" (dict "ctx" . "extra" .Values.deployment.annotations "provenance" true) }}
  annotations:
    {{- . | nindent 4 }}
  {{- end }}
*/}}
{{- define "workload.annotations" -}}
{{- $ctx := .ctx -}}
{{- $out := dict -}}
{{- range $k, $v := (.defaults | default dict) }}{{- $_ := set $out $k $v }}{{- end -}}
{{- if .provenance }}
{{- range $k, $v := (include "workload.provenanceAnnotations" $ctx | fromYaml | default dict) }}{{- $_ := set $out $k $v }}{{- end }}
{{- end -}}
{{- range $k, $v := ($ctx.Values.commonAnnotations | default dict) }}{{- $_ := set $out $k $v }}{{- end -}}
{{- range $k, $v := (.extra | default dict) }}{{- $_ := set $out $k $v }}{{- end -}}
{{- if $out }}
{{- toYaml $out }}
{{- end }}
{{- end }}

{{/*
workload.provenanceAnnotations — .Values.provenance rendered as OCI image-spec annotations.
Only non-empty fields are emitted:
  provenance.git.source       -> org.opencontainers.image.source
  provenance.git.revision     -> org.opencontainers.image.revision
  provenance.git.ref          -> org.opencontainers.image.ref.name
  provenance.git.version      -> org.opencontainers.image.version
  provenance.deploy.actor     -> org.opencontainers.image.authors
  provenance.deploy.timestamp -> org.opencontainers.image.created
*/}}
{{- define "workload.provenanceAnnotations" -}}
{{- $a := dict -}}
{{- $p := .Values.provenance | default dict -}}
{{- $git := $p.git | default dict -}}
{{- $deploy := $p.deploy | default dict -}}
{{- if $git.source }}{{- $a = set $a "org.opencontainers.image.source" $git.source -}}{{- end -}}
{{- if $git.revision }}{{- $a = set $a "org.opencontainers.image.revision" $git.revision -}}{{- end -}}
{{- if $git.ref }}{{- $a = set $a "org.opencontainers.image.ref.name" $git.ref -}}{{- end -}}
{{- if $git.version }}{{- $a = set $a "org.opencontainers.image.version" $git.version -}}{{- end -}}
{{- if $deploy.actor }}{{- $a = set $a "org.opencontainers.image.authors" $deploy.actor -}}{{- end -}}
{{- if $deploy.timestamp }}{{- $a = set $a "org.opencontainers.image.created" $deploy.timestamp -}}{{- end -}}
{{- if gt (len $a) 0 -}}
{{ toYaml $a }}
{{- end -}}
{{- end }}

{{/*
workload.isSet — renders "true" when the value is neither null nor an empty string, "" otherwise.
Unlike a bare `if`, it treats 0 and false as set, so `backoffLimit: 0` is rendered as 0.

Usage: {{- if include "workload.isSet" .Values.job.backoffLimit }}
*/}}
{{- define "workload.isSet" -}}
{{- if and (not (kindIs "invalid" .)) (ne (toString .) "") -}}true{{- end -}}
{{- end }}

{{/*
workload.serviceAccountName — ServiceAccount used by the pods. Empty means the namespace default.
*/}}
{{- define "workload.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- .Values.serviceAccount.name | default (include "workload.fullname" .) }}
{{- else }}
{{- .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
workload.image — the container image reference: repository, then :tag when a tag is set, then @digest when
one is set. A digest alone pins the image.
*/}}
{{- define "workload.image" -}}
{{- $ref := .Values.image.repository -}}
{{- if .Values.image.tag }}{{- $ref = printf "%s:%s" $ref (toString .Values.image.tag) -}}{{- end -}}
{{- if .Values.image.digest }}{{- $ref = printf "%s@%s" $ref .Values.image.digest -}}{{- end -}}
{{- $ref -}}
{{- end }}

{{/*
workload.workloadKind — the kind of the single enabled workload, or "" when none is enabled.
*/}}
{{- define "workload.workloadKind" -}}
{{- if .Values.deployment.enabled -}}Deployment
{{- else if .Values.statefulset.enabled -}}StatefulSet
{{- else if .Values.job.enabled -}}Job
{{- else if .Values.cronjob.enabled -}}CronJob
{{- end -}}
{{- end }}

{{/*
workload.servicePorts — the ports the Service exposes, as a YAML list of the entries from
.Values.ports. .Values.service.ports selects a subset by name; empty means all of them.
*/}}
{{- define "workload.servicePorts" -}}
{{- $byName := dict -}}
{{- range .Values.ports }}{{- $byName = set $byName .name . -}}{{- end -}}
{{- $names := list -}}
{{- if .Values.service.ports }}
{{- $names = .Values.service.ports }}
{{- else }}
{{- range .Values.ports }}{{- $names = append $names .name }}{{- end }}
{{- end -}}
{{- $out := list -}}
{{- range $names }}
{{- if not (hasKey $byName .) }}
{{- fail (printf "service.ports lists %q, which is not a name in ports (known: %s)" . (join ", " (keys $byName | sortAlpha))) }}
{{- end }}
{{- $out = append $out (index $byName .) }}
{{- end -}}
{{- if $out }}
{{- toYaml $out }}
{{- end }}
{{- end }}

{{/*
workload.headlessName — name of the headless Service. The fullname is shortened first, so the suffix never
pushes the name past 63 characters.
*/}}
{{- define "workload.headlessName" -}}
{{- printf "%s-headless" (include "workload.fullname" . | trunc 54 | trimSuffix "-") -}}
{{- end }}
