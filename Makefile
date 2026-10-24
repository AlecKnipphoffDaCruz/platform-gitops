CLUSTER  := k8s-practice
GH_USER  := AlecKnipphoffDaCruz
REGISTRY := ghcr.io/alecknipphoffdacruz
APPS     := app-front-a app-front-b
WORKDIR  := ..

.PHONY: help up down cluster argocd argocd-password root-app clone-apps build-apps status

help: ## Lista os comandos
	@grep -E '^[a-z-]+:.*##' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  make %-16s %s\n", $$1, $$2}'

up: cluster argocd ## Cria o cluster e instala o Argo CD

down: ## Apaga o cluster inteiro
	k3d cluster delete $(CLUSTER)

cluster: ## Cria o cluster k3d
	k3d cluster create --config bootstrap/k3d-cluster.yaml

argocd: ## Instala/atualiza o Argo CD
	kubectl apply -k bootstrap/argocd --server-side --force-conflicts
	kubectl -n argocd rollout status deploy/argocd-server --timeout=180s
	@echo "\nArgo CD: http://argocd.localhost  (usuário: admin, senha: make argocd-password)"

argocd-password: ## Mostra a senha inicial do admin do Argo
	@kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo

root-app: ## Liga o App of Apps (precisa do repo no GitHub)
	kubectl apply -f argocd/root-app.yaml

clone-apps: ## Clona os repos dos apps ao lado deste
	@for app in $(APPS); do \
		if [ -d $(WORKDIR)/$$app ]; then echo "$$app já existe"; \
		else gh repo clone $(GH_USER)/$$app $(WORKDIR)/$$app; fi; \
	done

build-apps: ## Builda as imagens localmente e joga direto no cluster (sem registry)
	@for app in $(APPS); do \
		docker build -t $(REGISTRY)/$$app:dev --build-arg APP_VERSION=local-dev $(WORKDIR)/$$app && \
		k3d image import -c $(CLUSTER) $(REGISTRY)/$$app:dev; \
	done

status: ## Visão geral do cluster
	kubectl get nodes
	kubectl get applications -n argocd 2>/dev/null || true
	kubectl get pods,svc,ingress -A -l app.kubernetes.io/name
