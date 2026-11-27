{{/*
workload.configmaps — every enabled ConfigMap in .Values.configMaps, one document each.
*/}}
{{- define "workload.configmaps" -}}
{{- range $name, $cm := .Values.configMaps }}
{{- if $cm.enabled }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "workload.fullname" $ }}-{{ $name }}
  labels:
    {{- include "workload.labels" $ | nindent 4 }}
  {{- with include "workload.annotations" (dict "ctx" $) }}
  annotations:
    {{- . | nindent 4 }}
  {{- end }}
data:
  {{- range $k, $v := $cm.data }}
  {{ $k | quote }}: {{ tpl ($v | toString) $ | quote }}
  {{- end }}
{{- end }}
{{- end }}
{{- end }}

{{/*
workload.configmapData — the rendered data of every enabled ConfigMap, and nothing else.
The pod checksum hashes this rather than the documents above, so a change to labels, annotations or
the chart version, none of which a pod reads, does not restart anything.
*/}}
{{- define "workload.configmapData" -}}
{{- $out := dict -}}
{{- range $name, $cm := .Values.configMaps }}
{{- if $cm.enabled }}
{{- $data := dict }}
{{- range $k, $v := $cm.data }}{{- $_ := set $data $k (tpl ($v | toString) $) }}{{- end }}
{{- $_ := set $out $name $data }}
{{- end }}
{{- end -}}
{{- toYaml $out -}}
{{- end }}
