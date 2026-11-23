# ModaExpress — GKE autoscaling

Base de treinamento para reproduzir o experimento descrito no paper do grupo.

## Objetivo
Implantar `php-apache` no GKE, configurar HPA com alvo de CPU de 70%, gerar carga e observar a expansão/redução de Pods e nós.

> A criação/configuração do cluster (Cluster Autoscaler e Node Auto-Provisioning) será fechada depois de conferirmos as etapas exatas do GSP768. Não execute comandos de criação de cluster às cegas.

## Configurações do paper
- Cluster: `scaling-demo`
- Zona: `us-central1-c`
- Nós iniciais: 3 `e2-medium`
- Deployment/Service: `php-apache`
- Imagem: `registry.k8s.io/hpa-example`
- CPU request: `200m`; CPU limit: `500m`
- Réplicas iniciais: 3
- HPA: alvo 70%, mínimo 1, máximo 10
- Cluster Autoscaler: paper descreve faixa de 1 a 5 nós
- Node Auto-Provisioning: habilitado; limites descritos: 1–45 vCPU e 2–160 GB RAM
- Carga: requisições a cada 10 ms
- Verificador: uma requisição por segundo, timeout de 2 s

## Estrutura
- `kubernetes/php-apache.yaml`: Deployment e Service
- `kubernetes/hpa.yaml`: HPA 70%, 1–10 réplicas
- `scripts/01-deploy-app.sh`: implanta aplicação e HPA
- `scripts/02-status.sh`: verifica HPA, Pods, Service, nós e métricas
- `scripts/03-start-load.sh`: inicia gerador de carga
- `scripts/04-start-checker.sh`: inicia verificador
- `scripts/05-stop-tests.sh`: interrompe os testes

## Pré-requisitos
- Laboratório GSP768 iniciado, com credenciais temporárias válidas
- Cluster `scaling-demo` criado e conectado no Cloud Shell
- `gcloud`, `kubectl` e acesso ao cluster funcionando

## Execução
1. Clone o repositório e entre na pasta.
2. Confira projeto, contexto e nós:
   ```bash
   gcloud config get-value project
   kubectl config current-context
   kubectl get nodes
   ```
3. Implante aplicação e HPA:
   ```bash
   bash scripts/01-deploy-app.sh
   ```
4. Confira:
   ```bash
   bash scripts/02-status.sh
   ```
5. Em outro terminal, inicie carga:
   ```bash
   bash scripts/03-start-load.sh
   ```
6. Opcionalmente, em outro terminal:
   ```bash
   bash scripts/04-start-checker.sh
   kubectl logs -f availability-checker
   ```
7. Observe:
   ```bash
   kubectl get hpa,pods,nodes --watch
   ```
8. Interrompa a carga:
   ```bash
   bash scripts/05-stop-tests.sh
   ```
9. Continue observando a redução das réplicas. O scale-down pode levar alguns minutos.

## O que demonstrar
- Cluster GKE ativo
- Deployment e Service `php-apache`
- HPA com alvo de CPU de 70%, mínimo 1 e máximo 10
- CPU acima do alvo durante o teste
- Aumento de Pods (paper relata 1 para 6)
- Nó adicional criado pelo NAP quando a capacidade existente não for suficiente
- Redução de recursos após interromper a carga

Os números do paper são resultados observados, não garantia de que toda execução repetirá exatamente a mesma sequência.

## Ressalvas
- HPA escala Pods; Cluster Autoscaler escala nós em node pools existentes; NAP pode criar novos node pools.
- `hpa-example` é uma aplicação Apache/PHP de demonstração que consome CPU, não uma loja virtual com catálogo e carrinho.
- O paper relata duas requisições com erro durante realocação de Pods, apesar de o verificador ter registrado respostas OK no período observado.
- A evidência final do paper mostra redução para duas réplicas; não afirma retorno completo a uma.
- Nunca salve senhas, credenciais temporárias ou chaves de serviço no GitHub.
- Ao terminar, remova os recursos conforme as instruções do laboratório.

## Referências
- Kubernetes HPA walkthrough: https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/
- Google Cloud Node Auto-Provisioning: https://cloud.google.com/kubernetes-engine/docs/how-to/node-auto-provisioning
- Google Skills GSP768: https://www.skills.google/focuses/15636
