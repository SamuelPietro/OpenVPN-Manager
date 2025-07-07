#  OpenVPN Manager

Um gerenciador interativo e automatizado para servidores OpenVPN, facilitando a criação, administração e remoção de instâncias, redes e usuários de VPN em servidores Linux.

## Descrição

Este projeto fornece um script Bash completo para gerenciar servidores OpenVPN de forma simples e eficiente, sem necessidade de conhecimento avançado em redes ou OpenVPN. Com um menu interativo, permite:

- Criar a Autoridade Certificadora (CA) e arquivos de configuração iniciais
- Criar novas instâncias/"clientes" de VPN, cada uma com múltiplas redes (sub-redes)
- Adicionar e remover usuários com IP fixo e geração automática do arquivo `.ovpn`
- Listar redes e usuários existentes
- Excluir redes, usuários ou instâncias inteiras, incluindo regras de firewall
- Gerenciar certificados, CRL e arquivos de configuração de forma automatizada

Ideal para provedores, empresas ou entusiastas que precisam gerenciar múltiplas redes e usuários OpenVPN de maneira centralizada e segura.



## Como Usar

1. **Pré-requisitos:**
   - Servidor Linux (Ubuntu recomendado)
   - OpenVPN, Easy-RSA e UFW instalados
   - Permissões de root

2. **Instalação:**
   - Clone este repositório ou copie o arquivo `openvpn-manager.sh` para seu servidor.
   - Dê permissão de execução:
     ```bash
     chmod +x openvpn-manager.sh
     ```
   - Caso ainda não tenha feito, instale as dependências necessárias
     ```bash
     apt update && apt install openvpn easy-rsa -y
     ```

3. **Configuração**
   
   **IP do Servidor:** Altere a variável `IP_SERVER` no script para o IP do seu servidor. Isso apenas preenche o valor padrão nos arquivos de configuração gerados. Se não configurar, não impactará o funcionamento do script.

   **Configuração de Redes:** As redes VPN serão criadas, por padrão, no formato `10.8.x.y`, onde:
   - `x` representa a camada da rede da respectiva VPN
   - `y` representa o IP fixo do usuário

   Você pode ajustar o prefixo das redes alterando a variável `PREFIXO_REDE` no script.

4. **Execução:**
   ```bash
   sudo ./openvpn-manager.sh
   ```
   Siga o menu interativo para criar CA, instâncias, redes e usuários.

## Funcionalidades

- **Menu interativo**: Interface amigável para todas as operações
- **Criação de CA**: Inicialização da infraestrutura de certificados
- **Gerenciamento de instâncias**: Cada cliente pode ter múltiplas redes
- **Gerenciamento de usuários**: Criação, listagem, revogação e exclusão
- **Geração automática de arquivos .ovpn**: Pronto para uso no cliente
- **Administração de firewall (UFW)**: Regras aplicadas automaticamente
- **Revogação e limpeza**: Certificados, arquivos e regras removidos de forma segura

## Licença

Distribuído sob a licença MIT. Consulte o arquivo LICENSE para mais informações.

## Contribuições

Contribuições são **bem-vindas e encorajadas**! Sinta-se à vontade para abrir issues, enviar pull requests ou sugerir melhorias.

> "De graça recebestes, de graça dai."

## Aviso

Este script é fornecido sem garantias. Use por sua conta e risco. Recomenda-se testar em ambiente de homologação antes de uso em produção.

---

**Autor:** Samuel Barbosa - StarUp Software Ltda

