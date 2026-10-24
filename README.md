# platform-gitops

Repo central do estudo de Kubernetes. Aqui fica o cluster, o Argo CD e os manifests de
todos os apps. Os outros repos só guardam código:

| Repo | O que tem |
|------|-----------|
| `platform-gitops` (este) | cluster local, Argo CD, manifests (Kustomize) |
| `app-front-a` | código do front A + Dockerfile + CI |
| `app-front-b` | código do front B + Dockerfile + CI |

```
k8s-practice/          ← pasta local, não é repo
├── platform-gitops/
├── app-front-a/
└── app-front-b/
```

## Como as coisas se conectam

```
push no app-front-a ──► CI builda imagem ──► publica no GHCR
                                         └─► commita a nova tag em apps/front-a/overlays/dev
                                                          │
Argo CD (no cluster) observa este repo ◄──────────────────┘
        └─► aplica a mudança no cluster ──► http://front-a.localhost
```

`argocd/root-app.yaml` é o **App of Apps**: uma Application que cria as outras
Applications que estão em `argocd/apps/`. Pra adicionar um app novo no cluster, basta
criar um arquivo nessa pasta.

## Estrutura

```
bootstrap/
  k3d-cluster.yaml      # definição do cluster local
  argocd/               # instalação do Argo CD (versão fixa) + ingress da UI
argocd/
  root-app.yaml         # App of Apps
  apps/                 # uma Application por app/ambiente
apps/
  front-a/
    base/               # Deployment, Service, Ingress (comum a todo ambiente)
    overlays/dev/       # o que muda no dev: namespace, réplicas, tag da imagem
  front-b/ ...
```

## Pré-requisitos

```bash
brew install k3d          # kubectl, docker e gh você já tem
```

O Docker Desktop precisa estar aberto.

## Comandos

```bash
make help              # lista tudo
make up                # cria o cluster + instala o Argo CD
make argocd-password   # senha do admin → http://argocd.localhost
make clone-apps        # clona os repos dos apps ao lado deste
make build-apps        # builda as imagens e importa no cluster (sem registry)
make root-app          # liga o App of Apps (precisa do repo no GitHub)
make status
make down              # apaga tudo
```

---

## Roteiro de estudo

Faça em ordem. Cada fase tem exercícios, então quebre as coisas de propósito.

### Fase 1: Kubernetes na mão (sem Argo)
```bash
make cluster
make build-apps
kubectl apply -k apps/front-a/overlays/dev
kubectl get all -n front-a-dev
open http://front-a.localhost
```
- [ ] `kubectl kustomize apps/front-a/overlays/dev`: veja o YAML final gerado
- [ ] Delete um pod e veja o Deployment recriar (`kubectl get pods -w`)
- [ ] `kubectl scale`, `kubectl logs`, `kubectl describe`, `kubectl exec`
- [ ] `kubectl port-forward svc/front-a 9000:80 -n front-a-dev`
- [ ] Quebre a readinessProbe (path errado) e veja o que acontece com o Service

### Fase 2: Recursos essenciais
- [ ] ConfigMap com uma mensagem que o front exibe
- [ ] Secret (e entenda por que base64 não é criptografia)
- [ ] HPA (precisa de metrics-server; o k3s já tem)
- [ ] Rolling update: mude a tag, veja `kubectl rollout status` e `rollout undo`
- [ ] PodDisruptionBudget e topologySpreadConstraints entre os 2 workers

### Fase 3: Ambientes
- [ ] Crie `overlays/prod` (namespace, 3 réplicas, host `front-a-prod.localhost`)
- [ ] Bônus: reescreva um dos apps como Helm chart e compare com Kustomize

### Fase 4: Argo CD
```bash
make argocd            # se ainda não instalou
# suba este repo pro GitHub (público) e:
make root-app
```
- [ ] Veja as Applications na UI
- [ ] Mude réplicas no Git, faça push e veja o Argo sincronizar
- [ ] Faça um `kubectl scale` manual e veja o selfHeal desfazer
- [ ] Apague um arquivo da base e veja o prune
- [ ] Crie `argocd/apps/front-a-prod.yaml` apontando para o overlay de prod

### Fase 5: CI fechando o ciclo GitOps
1. Suba `app-front-a` e `app-front-b` pro GitHub
2. Crie um token (fine-grained PAT) com **Contents: read and write** só no repo `platform-gitops`
3. Em cada repo de app, adicione o secret `GITOPS_TOKEN` com esse token
4. Depois do primeiro build, deixe o pacote **público** no GHCR
   (GitHub → Packages → app-front-a → Package settings → Change visibility).
   Assim o cluster consegue puxar a imagem sem credencial
- [ ] Mude um texto no front, faça push e veja a versão nova em `front-a.localhost`
- [ ] Bônus: deixe o pacote privado e configure um `imagePullSecret`

### Fase 6: Extras
- [ ] Prometheus + Grafana (kube-prometheus-stack via Argo)
- [ ] Sealed Secrets ou External Secrets
- [ ] NetworkPolicy: front-a não pode falar com front-b
- [ ] Argo Rollouts: deploy canary
- [ ] Argo CD gerenciando ele mesmo (`bootstrap/argocd` como Application)
