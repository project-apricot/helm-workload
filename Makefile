# Every tool runs from a pinned container image, so a checkout needs only Docker. To use a tool you
# already have, override its variable: `make HELM=helm HELM_UNITTEST="helm unittest" lint unittest`.

HELM_IMAGE          ?= alpine/helm:3.19.0
UNITTEST_IMAGE      ?= helmunittest/helm-unittest:3.19.0-1.0.3
KUBECONFORM_IMAGE   ?= ghcr.io/yannh/kubeconform:v0.7.0
HELM_DOCS_IMAGE     ?= jnorwood/helm-docs:v1.14.2

# Run as the current user, so nothing the tools write is owned by root.
DOCKER_RUN := docker run --rm -i --user "$(shell id -u):$(shell id -g)" -e HOME=/tmp -v "$(CURDIR)":/chart -w /chart

HELM         ?= $(DOCKER_RUN) $(HELM_IMAGE)
HELM_UNITTEST ?= $(DOCKER_RUN) $(UNITTEST_IMAGE)
KUBECONFORM  ?= $(DOCKER_RUN) $(KUBECONFORM_IMAGE)
HELM_DOCS    ?= $(DOCKER_RUN) $(HELM_DOCS_IMAGE)

# Kubernetes versions the rendered manifests are validated against.
KUBE_VERSIONS ?= 1.30.0 1.32.0 1.34.0

SCENARIOS := $(sort $(wildcard ci/*-values.yaml))
CRD_SCHEMAS := https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json

.PHONY: help all lint unittest kubeconform docs docs-check

help: ## Show this help
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-18s %s\n", $$1, $$2}'

all: lint unittest kubeconform docs-check ## Everything CI runs

lint: ## helm lint --strict with the defaults and every scenario
	$(HELM) lint --strict .
	@for f in $(SCENARIOS); do echo "==> $$f"; $(HELM) lint --strict . -f $$f || exit 1; done

unittest: ## Unit tests (helm-unittest)
	$(HELM_UNITTEST) .

kubeconform: ## Validate every scenario's manifests against each Kubernetes version
	@for v in $(KUBE_VERSIONS); do for f in $(SCENARIOS); do \
	  echo "==> k8s $$v  $$f"; \
	  $(HELM) template example . -f $$f --kube-version $$v \
	    | $(KUBECONFORM) -strict -summary -kubernetes-version $$v \
	        -schema-location default -schema-location '$(CRD_SCHEMAS)' - || exit 1; \
	done; done

docs: ## Regenerate docs/values.mdx from values.yaml
	$(HELM_DOCS) --chart-search-root . --sort-values-order file \
	  --template-files docs/values.mdx.gotmpl --output-file docs/values.mdx

docs-check: ## Fail if docs/values.mdx is out of date
	@before=$$(cksum < docs/values.mdx 2>/dev/null); \
	$(MAKE) --no-print-directory docs >/dev/null 2>&1; \
	after=$$(cksum < docs/values.mdx); \
	[ "$$before" = "$$after" ] || { echo "docs/values.mdx was out of date and has been regenerated: commit it"; exit 1; }
