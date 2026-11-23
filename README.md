# Entendendo e combinando estratégias de escalonamento automático do GKE

## ModaExpress — roteiro de apresentação (preparação + demonstração)

**Laboratório de referência:** Google Skills Boost — **GSP768: Entendendo e combinando estratégias de escalonamento automático do GKE**. Acesse [Google Skills](https://www.cloudskillsboost.google/) e procure pelo título ou código **GSP768**. Inicie o laboratório, abra **Google Cloud Console**, clique em **Ativar Cloud Shell** e autorize o acesso. **Não é Google Colab**: os comandos deste projeto são executados no terminal do **Cloud Shell**.

**Atenção:** o laboratório fornece credenciais e projeto temporários. Inicie-o com tempo suficiente para preparar e apresentar tudo antes de expirar. Ao reiniciar o laboratório, você pode receber outro projeto vazio. Se usar conta própria, verifique custos e permissões.

## Checklist: o que fazer em cada momento

| Etapa | Momento | Por quê |
|---|---|---|
| Abrir GSP768, Console e Cloud Shell | **ANTES** | Deixar o terminal pronto |
| Conferir projeto e definir zona | **ANTES** | Evitar executar em projeto errado |
| Criar cluster `scaling-demo` (se ainda não existe) | **ANTES** | Pode demorar vários minutos |
| Conectar `kubectl` ao cluster | **ANTES** | Administrar o Kubernetes |
| Habilitar autoscaling dos nós (e opcionalmente NAP) | **ANTES** | Preparar a infraestrutura |
| Clonar GitHub e executar `01-deploy-app.sh` | **ANTES** | Deixar a aplicação e o HPA 70% prontos |
| Verificar `kubectl get hpa` e `kubectl get nodes` | **ANTES** | Garantir que não há erros |
| Mostrar estado inicial com `02-status.sh` | **AO VIVO** | Mostrar a capacidade antes do pico |
| Iniciar `03-start-load.sh` | **AO VIVO** | Simular aumento de acessos |
| Iniciar `04-start-checker.sh` (opcional) | **AO VIVO** | Verificar respostas durante o teste |
| Mostrar HPA, Deployment e nós | **AO VIVO** | Comprovar o que escalou |
| Parar com `05-stop-tests.sh` | **AO VIVO** | Simular fim da promoção |
| Aguardar e consultar HPA novamente | **AO VIVO**, se houver tempo | Mostrar a redução (pode levar minutos) |

**Importante:** execute **somente** a configuração de cluster do laboratório e a implantação da aplicação **do GitHub**. Não execute também a tarefa do laboratório que cria outro `php-apache`, porque os manifestos podem entrar em conflito. O laboratório é a referência para preparar o GKE; o GitHub é a fonte dos scripts da demonstração.

---

> **Objetivo:** demonstrar, usando uma aplicação PHP/Apache de exemplo, como o Kubernetes aumenta e diminui automaticamente a quantidade de Pods quando a demanda muda. O exemplo representa a carga de uma loja virtual chamada ModaExpress; **não é uma loja completa**.
>
> **Meta do projeto:** HPA com utilização média de CPU de **70%**, mínimo de **1** e máximo de **10 Pods**.

## 1. O que dizer na abertura

> “Nosso trabalho simula uma loja virtual em uma promoção. Quando muitos clientes acessam ao mesmo tempo, a aplicação precisa de mais capacidade. Vamos mostrar como o GKE, com o Horizontal Pod Autoscaler, cria mais cópias da aplicação automaticamente e reduz essa quantidade quando os acessos diminuem.”

**Termos para entender:**

- **GKE:** serviço do Google Cloud que executa e administra clusters Kubernetes.
- **Cluster:** conjunto de máquinas que executam a aplicação.
- **Nó (node):** uma máquina do cluster.
- **Pod:** unidade do Kubernetes que executa um contêiner; aqui, cada Pod executa uma cópia do exemplo PHP/Apache.
- **Deployment:** define e mantém as cópias da aplicação.
- **Service:** fornece um endereço interno estável para acessar os Pods.
- **HPA:** aumenta ou reduz a quantidade de Pods de acordo com a utilização de CPU.
- **Cluster Autoscaler:** aumenta ou reduz a quantidade de máquinas quando a capacidade do cluster exige.
- **Node Auto-Provisioning:** pode criar novos grupos de máquinas conforme a necessidade.

## 2. ANTES: preparar o Google Cloud no laboratório GSP768

**Atenção:** o projeto do Google Skills usa credenciais temporárias e expira. Prepare um projeto autorizado e com recursos disponíveis para o horário da apresentação. Criar e manter um cluster em projeto próprio pode gerar cobrança. Os comandos abaixo pressupõem que o Cloud Shell está autenticado, que o projeto correto foi selecionado e que há permissões/cotas suficientes.

No **Google Cloud Console**, abra o **Cloud Shell**. Confira o projeto:

```bash
gcloud config get-value project
```

**O que faz:** mostra em qual projeto do Google Cloud os comandos serão executados.

Defina a zona usada no experimento:

```bash
gcloud config set compute/zone us-central1-c
```

**O que faz:** define a região/zona das máquinas do cluster.

Crie o cluster (faça isso **antes**, pois pode levar vários minutos):

```bash
gcloud container clusters create scaling-demo --num-nodes=3 --enable-vertical-pod-autoscaling
```

**O que faz:** cria o cluster `scaling-demo` com três nós iniciais. A opção de VPA reproduz a preparação do laboratório; **não precisamos demonstrar VPA** no experimento principal.

Se o cluster já existir, **não execute a criação novamente**. Para reconectar o Cloud Shell a ele, use:

```bash
gcloud container clusters get-credentials scaling-demo --zone us-central1-c
```

**O que faz:** configura o `kubectl` para administrar o cluster existente.

Habilite o escalonamento do pool de nós:

```bash
gcloud beta container clusters update scaling-demo --enable-autoscaling --min-nodes 1 --max-nodes 5
```

**O que faz:** permite que o pool de máquinas aumente ou diminua entre 1 e 5 nós, conforme a necessidade. **Isso não garante que novos nós aparecerão em todo teste**: só ocorre quando os Pods precisam de capacidade adicional.

Configure o perfil usado no laboratório:

```bash
gcloud beta container clusters update scaling-demo --autoscaling-profile optimize-utilization
```

**O que faz:** prioriza o aproveitamento dos recursos, ajudando a reduzir nós ociosos.

Se a demonstração também incluir **Node Auto-Provisioning**, habilite-o como no Google Skills:

```bash
gcloud beta container clusters update scaling-demo --zone us-central1-c --enable-autoprovisioning --min-cpu 1 --min-memory 2 --max-cpu 45 --max-memory 160
```

**O que faz:** autoriza o GKE a criar novos pools de nós, respeitando limites de CPU e memória do cluster. **É opcional para comprovar o HPA** e pode demorar. Use `gcloud beta` nesta etapa, pois a versão estável do comando utilizada anteriormente não reconheceu esses parâmetros. Execute tudo em uma única linha.

Confira os nós:

```bash
kubectl get nodes
```

**O que faz:** lista as máquinas do cluster e seu estado. `Ready` significa que a máquina está pronta.

## 3. ANTES: clonar nosso projeto do GitHub

No Cloud Shell, execute:

```bash
git clone https://github.com/Pedro-FB-ECO/modaexpress-gke.git
```

**O que faz:** baixa os arquivos do nosso projeto para o terminal do Google Cloud.

Entre na pasta:

```bash
cd modaexpress-gke
```

**O que faz:** coloca o terminal na pasta que contém os manifestos e scripts.

Veja os arquivos:

```bash
ls kubernetes scripts
```

**O que faz:** mostra os arquivos de configuração e os scripts de teste.

**O que dizer:** “Colocamos os arquivos no GitHub para organizar a configuração, documentar os testes e permitir que o experimento seja reproduzido.”

## 4. ANTES: implantar a aplicação e configurar o HPA em 70%

O arquivo `kubernetes/php-apache.yaml` define um **Deployment com três réplicas iniciais**, a imagem `registry.k8s.io/hpa-example`, solicitação de CPU de `200m`, limite de `500m` e um Service interno chamado `php-apache`.

O arquivo `kubernetes/hpa.yaml` define o **HPA de 70%**, com mínimo de **1** e máximo de **10 Pods**.

Execute o script do repositório:

```bash
bash scripts/01-deploy-app.sh
```

**O que faz:** verifica o projeto/cluster, implanta o PHP/Apache e aplica a configuração de HPA de 70%. Aguarda a aplicação ficar pronta.

> **Atenção:** se você estiver reutilizando o cluster do Google Skills, onde já existe um Deployment `php-apache` criado manualmente com rótulos diferentes, a aplicação do YAML do GitHub **pode falhar** porque o seletor de um Deployment não pode ser alterado. O roteiro mais seguro é usar um cluster limpo para o projeto ou preparar antecipadamente a migração. Não exclua recursos do laboratório sem confirmar o contexto.

Verifique o HPA:

```bash
kubectl get hpa
```

**O que faz:** mostra o consumo atual de CPU, a meta de 70%, os limites e o número de réplicas.

**Como ler `cpu: 126%/70%`:** o primeiro valor é o uso atual em relação à CPU solicitada; o segundo é a meta. Não significa 126% da capacidade física total do computador.

**O que dizer:** “Configuramos o HPA para buscar uma utilização média de 70% da CPU solicitada. Quando a carga fica acima da meta, ele pode criar mais Pods.”

## 5. AO VIVO: mostrar a situação antes do pico

Verifique o estado:

```bash
bash scripts/02-status.sh
```

**O que faz:** mostra o HPA, a aplicação, os Pods, os nós e, quando disponíveis, métricas de CPU.

**O que observar:** com pouco ou nenhum acesso, o HPA pode reduzir as réplicas até **1 Pod**. Isso **não acontece imediatamente**; espere o tempo necessário para a estabilização.

**O que dizer:** “Em um período de poucos acessos, o sistema não precisa manter tantas cópias funcionando.”

## 6. AO VIVO: simular a promoção e aumentar os acessos

Inicie o gerador de carga do nosso GitHub:

```bash
bash scripts/03-start-load.sh
```

**O que faz:** cria um Pod `load-generator` que faz solicitações repetidas ao Service interno `php-apache`, com intervalo de aproximadamente 0,01 segundo após cada solicitação. O comando inicia o Pod; ele não precisa manter o terminal ocupado.

Opcionalmente, inicie o verificador de disponibilidade:

```bash
bash scripts/04-start-checker.sh
```

**O que faz:** cria outro Pod que tenta acessar a aplicação aproximadamente a cada segundo e registra `OK` ou `FALHA` (com timeout de 2 segundos). **Esse teste não mede disponibilidade de produção nem garante ausência de falhas.**

Acompanhe o HPA:

```bash
kubectl get hpa
```

**O que observar:** o consumo pode ultrapassar `70%`, e a quantidade em `REPLICAS` pode aumentar.

Veja as cópias disponíveis:

```bash
kubectl get deployment php-apache
```

**Como ler `6/6`:** seis cópias estão prontas, de seis desejadas. Se aparecer `3/6`, o sistema quer seis, mas somente três estão prontas naquele momento.

**O que dizer:** “Simulamos muitos clientes entrando na ModaExpress. O HPA percebeu o aumento de uso de CPU e elevou o número de Pods para atender à demanda.”

> **Resultado já observado no ensaio:** a implantação chegou a `6/6` com o HPA em 70%. Na apresentação, diga o número que realmente aparecer no terminal; ele pode variar.

## 7. AO VIVO: verificar se as máquinas também aumentaram

```bash
kubectl get nodes
```

**O que faz:** mostra quantas máquinas estão disponíveis no cluster.

**O que dizer:** “O HPA cria mais Pods. Se não houver espaço suficiente nas máquinas, o Cluster Autoscaler pode adicionar nós. Vamos verificar se isso aconteceu neste teste.”

**Importante:** aumentar Pods **não significa obrigatoriamente** aumentar nós. Se houver capacidade sobrando, os novos Pods podem usar as máquinas existentes. Não afirme que houve escalonamento de nós sem mostrar evidência no comando ou na guia **Kubernetes Engine → Clusters → scaling-demo → Nós**.

## 8. AO VIVO: simular o fim da promoção

Encerre os testes:

```bash
bash scripts/05-stop-tests.sh
```

**O que faz:** exclui os Pods `load-generator` e `availability-checker`, interrompendo os acessos artificiais.

Após alguns minutos, acompanhe a redução:

```bash
kubectl get hpa
```

**O que observar:** a CPU diminui e, após a janela de estabilização, o HPA tende a reduzir a quantidade de Pods, respeitando o mínimo de 1. A redução dos **nós** pode demorar mais e não é garantida no tempo da apresentação.

**O que dizer:** “Quando a promoção acaba e o movimento diminui, o Kubernetes reduz as cópias desnecessárias, ajudando a evitar desperdício de recursos.”

## 9. AO VIVO: consultar o verificador de disponibilidade (opcional)

Enquanto o verificador estiver em execução:

```bash
kubectl logs availability-checker --tail=20
```

**O que faz:** exibe as 20 mensagens mais recentes do teste de disponibilidade. `OK` indica uma resposta recebida naquela tentativa; `FALHA` indica que aquela tentativa não conseguiu obter resposta no prazo.

## 10. Encerramento: fala sugerida

> “Com esse experimento, mostramos que o GKE consegue adaptar a quantidade de Pods à demanda da aplicação. Durante o pico de acessos, o HPA aumentou as cópias do PHP/Apache. Depois que interrompemos a carga, o sistema pôde reduzir os recursos novamente. O escalonamento de nós complementa esse processo quando a capacidade das máquinas não é suficiente. Essa é a ideia aplicada ao cenário de promoções da ModaExpress.”

## 11. Resumo dos arquivos do repositório

| Arquivo | Função |
|---|---|
| `kubernetes/php-apache.yaml` | Define a aplicação e seu Service interno |
| `kubernetes/hpa.yaml` | Define HPA com meta de CPU de 70%, mínimo 1 e máximo 10 Pods |
| `scripts/01-deploy-app.sh` | Implanta a aplicação e aplica o HPA |
| `scripts/02-status.sh` | Consulta estado da aplicação, Pods, HPA e nós |
| `scripts/03-start-load.sh` | Inicia a simulação de muitos acessos |
| `scripts/04-start-checker.sh` | Inicia verificações periódicas de disponibilidade |
| `scripts/05-stop-tests.sh` | Encerra os dois Pods de teste |

## 12. Cuidados para não ter surpresa

1. **Não dependa da conta temporária do Google Skills** para uma apresentação fora do período do laboratório.
2. **Confirme o projeto e o contexto do Kubernetes** antes de executar comandos; clusters GKE podem gerar custos em contas próprias.
3. **Não misture os manifestos do laboratório e do GitHub no mesmo Deployment sem preparação:** eles usam seletores diferentes.
4. **O HPA escala Pods; o Cluster Autoscaler escala nós.** São mecanismos diferentes.
5. **Os resultados variam** conforme CPU, recursos disponíveis, tempo de execução e comportamento do GKE.
6. **A redução demora.** Para uma apresentação curta, prepare capturas do ensaio como apoio, identificando-as claramente como resultados anteriores.
7. **O laboratório inclui VPA, PDB e Pod pausado** como exercícios adicionais; eles não precisam ser demonstrados para explicar o HPA do projeto.
8. **Ao terminar em projeto próprio, exclua os recursos que não serão mais usados**, seguindo as regras da conta, para evitar cobranças futuras.

---

**Fonte do procedimento de infraestrutura:** laboratório Google Skills GSP768, “Entendendo e combinando estratégias de escalonamento automático do GKE”. **Fonte dos scripts de aplicação:** repositório `Pedro-FB-ECO/modaexpress-gke`. O roteiro diferencia os comandos do laboratório dos scripts do projeto e não presume que os dois ambientes sejam idênticos.
