{{/*
workload.externalsecrets — every enabled ExternalSecret in .Values.externalSecrets, one document each.

The fields in .Values.externalSecretDefaults are rendered explicitly, whether or not the operator
would fill them in. A field the operator defaults server-side otherwise exists on the live object
and not in the manifest, which GitOps tools report as permanent drift.
*/}}
{{- define "workload.externalsecrets" -}}
{{- range $name, $es := .Values.externalSecrets }}
{{- if $es.enabled }}
---
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: {{ include "workload.fullname" $ }}-{{ $name }}
  labels:
    {{- include "workload.labels" $ | nindent 4 }}
  {{- with include "workload.annotations" (dict "ctx" $) }}
  annotations:
    {{- . | nindent 4 }}
  {{- end }}
spec:
  {{- include "workload.externalsecretSpec" (dict "ctx" $ "name" $name "es" $es) | nindent 2 }}
{{- end }}
{{- end }}
{{- end }}

{{/*
workload.externalsecretSpec — the spec of one ExternalSecret, at column 0.
Takes a dict: ctx (the root context), name (the key in .Values.externalSecrets), es (its value).
*/}}
{{- define "workload.externalsecretSpec" -}}
{{- $ctx := .ctx -}}
{{- $es := .es -}}
{{- $defaults := $ctx.Values.externalSecretDefaults | default dict -}}
{{- $storeName := required (printf "externalSecrets.%s: set secretStoreRef.name or cluster.clusterSecretStore" .name) (($es.secretStoreRef).name | default $ctx.Values.cluster.clusterSecretStore) -}}
refreshInterval: {{ $es.refreshInterval | default "1h" }}
secretStoreRef:
  name: {{ $storeName }}
  kind: {{ ($es.secretStoreRef).kind | default "ClusterSecretStore" }}
target:
  name: {{ include "workload.fullname" $ctx }}-{{ .name }}
  creationPolicy: Owner
  {{- with $defaults.deletionPolicy }}
  deletionPolicy: {{ . }}
  {{- end }}
data:
  {{- range $localKey, $remoteKey := $es.remoteRefs }}
  - secretKey: {{ $localKey | quote }}
    remoteRef:
      key: {{ $remoteKey | quote }}
      {{- with $defaults.conversionStrategy }}
      conversionStrategy: {{ . }}
      {{- end }}
      {{- with $defaults.decodingStrategy }}
      decodingStrategy: {{ . }}
      {{- end }}
      {{- with $defaults.metadataPolicy }}
      metadataPolicy: {{ . }}
      {{- end }}
      {{- with $defaults.nullBytePolicy }}
      nullBytePolicy: {{ . }}
      {{- end }}
  {{- end }}
{{- end }}

{{/*
workload.externalsecretSpecs — the specs of every enabled ExternalSecret, and nothing else.
The pod checksum hashes this rather than the documents, for the same reason as workload.configmapData.
*/}}
{{- define "workload.externalsecretSpecs" -}}
{{- range $name, $es := .Values.externalSecrets }}
{{- if $es.enabled }}
{{ $name }}:
  {{- include "workload.externalsecretSpec" (dict "ctx" $ "name" $name "es" $es) | nindent 2 }}
{{- end }}
{{- end }}
{{- end }}
