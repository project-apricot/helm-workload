{{/*
workload.podTemplate — the pod template shared by Deployment, StatefulSet, Job and CronJob.
Renders `metadata` and `spec` at column 0; callers indent it under `template:`.

Takes a dict:
  ctx            the root context
  restartPolicy  set for Job and CronJob pods
  probes         true for long-running workloads (Deployment, StatefulSet): adds ports and probes
  vcts           true for a StatefulSet: mounts its volumeClaimTemplates

ConfigMaps, ExternalSecrets and PVCs are wired in automatically:
  asEnv      -> envFrom
  mountPath  -> volume + volumeMount
*/}}
{{- define "workload.podTemplate" -}}
{{- $ctx := .ctx -}}
{{- $v := $ctx.Values -}}
{{- $fullname := include "workload.fullname" $ctx -}}

{{- $envFromCMs := list -}}
{{- $fileCMs := list -}}
{{- range $name, $cm := $v.configMaps }}
{{- if $cm.enabled }}
{{- if $cm.asEnv }}{{- $envFromCMs = append $envFromCMs $name }}{{- end }}
{{- if $cm.mountPath }}{{- $fileCMs = append $fileCMs (dict "name" $name "mountPath" $cm.mountPath) }}{{- end }}
{{- end }}
{{- end -}}

{{- $envFromSecrets := list -}}
{{- $fileSecrets := list -}}
{{- range $name, $es := $v.externalSecrets }}
{{- if $es.enabled }}
{{- if $es.asEnv }}{{- $envFromSecrets = append $envFromSecrets $name }}{{- end }}
{{- if $es.mountPath }}{{- $fileSecrets = append $fileSecrets (dict "name" $name "mountPath" $es.mountPath) }}{{- end }}
{{- end }}
{{- end -}}

{{- $filePVCs := list -}}
{{- range $name, $pvc := $v.persistentVolumeClaims }}
{{- if $pvc.mountPath }}
{{- $filePVCs = append $filePVCs (dict "name" $name "mountPath" $pvc.mountPath) }}
{{- end }}
{{- end -}}

{{- $fileVCTs := list -}}
{{- if .vcts }}
{{- range $name, $vct := $v.statefulset.volumeClaimTemplates }}
{{- if $vct.mountPath }}
{{- $fileVCTs = append $fileVCTs (dict "name" $name "mountPath" $vct.mountPath) }}
{{- end }}
{{- end }}
{{- end -}}

{{- $checksums := dict -}}
{{- if $v.configMaps }}{{- $_ := set $checksums "checksum/configmaps" (include "workload.configmapData" $ctx | sha256sum) -}}{{- end -}}
{{- if $v.externalSecrets }}{{- $_ := set $checksums "checksum/externalsecrets" (include "workload.externalsecretSpecs" $ctx | sha256sum) -}}{{- end -}}
{{- $podAnnotations := merge (dict) ($v.podAnnotations | default dict) $checksums -}}

{{- $pullSecret := coalesce $v.image.pullSecret $v.cluster.imagePullSecret -}}
{{- $serviceAccount := include "workload.serviceAccountName" $ctx -}}
metadata:
  labels:
    {{- include "workload.podLabels" $ctx | nindent 4 }}
  {{- with $podAnnotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- if .restartPolicy }}
  restartPolicy: {{ .restartPolicy }}
  {{- end }}
  {{- if $pullSecret }}
  imagePullSecrets:
    - name: {{ $pullSecret }}
  {{- end }}
  {{- if $serviceAccount }}
  serviceAccountName: {{ $serviceAccount }}
  {{- end }}
  {{- if include "workload.isSet" $v.serviceAccount.automountServiceAccountToken }}
  automountServiceAccountToken: {{ $v.serviceAccount.automountServiceAccountToken }}
  {{- end }}
  {{- if $v.podSecurityContext.enabled }}
  securityContext:
    {{- omit $v.podSecurityContext "enabled" | toYaml | nindent 4 }}
  {{- end }}
  {{- with $v.priorityClassName }}
  priorityClassName: {{ . }}
  {{- end }}
  {{- if include "workload.isSet" $v.terminationGracePeriodSeconds }}
  terminationGracePeriodSeconds: {{ $v.terminationGracePeriodSeconds | int64 }}
  {{- end }}
  {{- with $v.nodeSelector }}
  nodeSelector:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $v.affinity }}
  affinity:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $v.tolerations }}
  tolerations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $v.topologySpreadConstraints }}
  topologySpreadConstraints:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $v.initContainers }}
  initContainers:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  containers:
    - name: {{ include "workload.name" $ctx | quote }}
      image: {{ include "workload.image" $ctx }}
      imagePullPolicy: {{ $v.image.pullPolicy | default "IfNotPresent" }}
      {{- with $v.command }}
      command:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with $v.args }}
      args:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- if $v.containerSecurityContext.enabled }}
      securityContext:
        {{- omit $v.containerSecurityContext "enabled" | toYaml | nindent 8 }}
      {{- end }}
      {{- with $v.resources }}
      resources:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with $v.env }}
      env:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- if or $envFromCMs $envFromSecrets $v.extraConfigMapRefs $v.extraSecretRefs }}
      envFrom:
        {{- range $envFromCMs }}
        - configMapRef:
            name: {{ $fullname }}-{{ . }}
        {{- end }}
        {{- range $v.extraConfigMapRefs }}
        - configMapRef:
            name: {{ . }}
        {{- end }}
        {{- range $envFromSecrets }}
        - secretRef:
            name: {{ $fullname }}-{{ . }}
        {{- end }}
        {{- range $v.extraSecretRefs }}
        - secretRef:
            name: {{ . }}
        {{- end }}
      {{- end }}
      {{- if .probes }}
      {{- with $v.ports }}
      ports:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with $v.livenessProbe }}
      livenessProbe:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with $v.readinessProbe }}
      readinessProbe:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with $v.startupProbe }}
      startupProbe:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- end }}
      {{- with $v.lifecycle }}
      lifecycle:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- if or $fileCMs $fileSecrets $filePVCs $fileVCTs $v.extraVolumeMounts }}
      volumeMounts:
        {{- range $fileCMs }}
        - name: {{ .name }}
          mountPath: {{ .mountPath }}
          readOnly: true
        {{- end }}
        {{- range $fileSecrets }}
        - name: {{ .name }}
          mountPath: {{ .mountPath }}
          readOnly: true
        {{- end }}
        {{- range $filePVCs }}
        - name: {{ .name }}
          mountPath: {{ .mountPath }}
        {{- end }}
        {{- range $fileVCTs }}
        - name: {{ .name }}
          mountPath: {{ .mountPath }}
        {{- end }}
        {{- with $v.extraVolumeMounts }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      {{- end }}
    {{- with $v.extraContainers }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  {{- if or $fileCMs $fileSecrets $filePVCs $v.extraVolumes }}
  volumes:
    {{- range $fileCMs }}
    - name: {{ .name }}
      configMap:
        name: {{ $fullname }}-{{ .name }}
    {{- end }}
    {{- range $fileSecrets }}
    - name: {{ .name }}
      secret:
        secretName: {{ $fullname }}-{{ .name }}
    {{- end }}
    {{- range $filePVCs }}
    - name: {{ .name }}
      persistentVolumeClaim:
        claimName: {{ $fullname }}-{{ .name }}
    {{- end }}
    {{- with $v.extraVolumes }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  {{- end }}
{{- end }}
