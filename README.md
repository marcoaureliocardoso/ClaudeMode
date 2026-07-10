# claude-mode

Gerenciador de modos por projeto para manter simultaneamente instalados:

- o skillset Nori `senior-swe`;
- o plugin `superpowers` do Claude Code.

A ferramenta garante que apenas um comportamento fique ativo de cada vez.

## Modos

| Modo | Nori | Superpowers |
|---|---|---|
| `senior` | `senior-swe` ativo | instalado, desabilitado no escopo `local` |
| `superpowers` | `claude-mode-neutral` ativo | habilitado no escopo `local` |
| `none` | configuração Nori do projeto removida | componente criado pela ferramenta removido ou estado preexistente restaurado |

O skillset `claude-mode-neutral` é vazio e existe apenas para retirar as instruções do `senior-swe` sem desinstalar o Nori.

## Requisitos

- Linux ou macOS;
- Bash 3.2 ou superior;
- Python 3;
- Claude Code com suporte a `claude plugin`;
- Git, salvo ao usar `--project` com `--allow-non-git`;
- Node.js/npm quando o Nori ainda não estiver instalado.

Documentação consultada:

- https://code.claude.com/docs/en/plugins-reference
- https://github.com/tilework-tech/nori-skillsets
- https://github.com/obra/superpowers

## Instalação da ferramenta

No diretório extraído:

```bash
./install.sh
```

Por padrão, os arquivos são copiados para:

```text
~/.local/lib/claude-mode
~/.local/bin/claude-mode
```

Garanta que `~/.local/bin` esteja no `PATH`.

Também é possível executar diretamente do repositório:

```bash
./bin/claude-mode --help
```

## Instalação concomitante no projeto

Execute na raiz do projeto:

```bash
claude-mode install
```

Em um diretório sem Git:

```bash
claude-mode --project /caminho/do/projeto --allow-non-git install
```

A instalação:

1. registra o estado original;
2. instala o Nori via npm somente quando necessário;
3. inicializa o Nori com o diretório do projeto explicitamente informado;
4. baixa `senior-swe` quando ausente;
5. cria o skillset vazio `claude-mode-neutral`;
6. instala Superpowers no escopo Claude Code `local`;
7. desabilita Superpowers;
8. ativa `senior-swe`;
9. verifica o modo observado.

A operação é idempotente. Repetir `install` não duplica o plugin nem o skillset neutro.

## Chaveamento

### Ativar o perfil generalista

```bash
claude-mode use senior
```

A ordem é:

```text
Superpowers OFF → Nori senior-swe
```

### Ativar a metodologia Superpowers

```bash
claude-mode use superpowers
```

A ordem é:

```text
Nori claude-mode-neutral → Superpowers ON
```

Depois de qualquer chaveamento, encerre a sessão atual e inicie uma nova sessão do Claude Code. O histórico da conversa pode manter instruções que já entraram no contexto.

## Estado e diagnóstico

```bash
claude-mode status
claude-mode status --json
claude-mode doctor
claude-mode doctor --json
```

`status` consulta o estado real do marcador Nori e de `claude plugin list --json`; ele não confia apenas no arquivo salvo.

`doctor` retorna código diferente de zero quando encontra problemas, incluindo:

- mais de uma instalação do Superpowers;
- Superpowers fora do escopo `local`;
- `senior-swe` e Superpowers ativos simultaneamente;
- modo salvo divergente do observado;
- skillset neutro modificado;
- ferramentas ausentes.

## Simulação

```bash
claude-mode --dry-run install
claude-mode --dry-run use superpowers
claude-mode --dry-run --yes uninstall
```

O modo de simulação não cria lock, estado ou arquivos de configuração.

## Desinstalação limpa

```bash
claude-mode --yes uninstall
```

A desinstalação normal:

- remove a configuração Nori do projeto;
- remove `claude-mode-neutral` somente quando foi criado pela ferramenta e continua intacto;
- desinstala Superpowers somente quando foi instalado pela ferramenta;
- restaura o estado habilitado/desabilitado quando o plugin já existia;
- preserva `senior-swe`;
- preserva Nori globalmente;
- mantém estado, logs e backups para auditoria.

Para remover também o pacote global do Nori:

```bash
claude-mode --yes --purge-global uninstall
```

A purga é recusada quando:

- o Nori não foi instalado por esta ferramenta;
- existe outro projeto conhecido com `claude-mode` instalado.

A ferramenta nunca executa `nori-skillsets factory-reset claude-code`.

## Estado persistente e backups

O estado fica em:

```text
${XDG_STATE_HOME:-$HOME/.local/state}/claude-mode/<hash-do-projeto>/
```

Arquivos principais:

```text
state.json
backups/claude-settings.before.json
backups/claude-settings.after-nori.json
backups/claude-settings.before-uninstall.json
backups/claude-settings.merged.json
backups/settings-conflicts.json
```

As gravações JSON são atômicas e usam permissões restritas.

## Preservação de `settings.json`

O Nori modifica `~/.claude/settings.json`, mesmo em uma instalação associada a um projeto. Para evitar que o mecanismo de backup do Nori reverta alterações posteriores, `claude-mode` realiza uma mesclagem de três vias:

```text
estado anterior ao Nori
estado imediatamente depois do Nori
estado atual antes da desinstalação
```

Alterações do usuário em chaves não tocadas pelo Nori são mantidas. Em conflitos escalares, o valor atual do usuário é preservado e o caminho aparece em `settings-conflicts.json`.

## Rollback

Operações mutáveis criam uma fotografia transacional de `~/.claude/settings.json` e registram o modo anterior. Quando uma operação falha, o handler de saída tenta:

1. restaurar a fotografia das configurações;
2. restaurar o skillset Nori anterior;
3. restaurar o estado anterior do plugin;
4. remover um plugin criado durante uma instalação incompleta;
5. liberar o lock.

O rollback é de melhor esforço. Depois de uma falha:

```bash
claude-mode doctor
claude-mode status --json
```

## Concorrência

Cada projeto usa um lock baseado em diretório. Locks cujo PID ainda está vivo bloqueiam a operação. Locks abandonados são removidos na próxima execução.

## Segurança

- caminhos são canonicalizados;
- `/` e `$HOME` são recusados como raiz de projeto;
- o plugin é manipulado apenas pela CLI oficial do Claude Code;
- o registro interno de plugins não é editado diretamente;
- ações globais exigem `--purge-global --yes`;
- múltiplas instalações do Superpowers causam abortagem, não escolha arbitrária;
- o skillset neutro modificado nunca é apagado automaticamente;
- expansões de caminhos são colocadas entre aspas;
- o script usa `set -Eeuo pipefail` e `umask 077`.

## Testes

```bash
make test
make verify
```

Os testes usam executáveis falsos em um `PATH` temporário e não alteram instalações reais do Claude Code, Nori ou npm.

Cobertura comportamental atual:

- instalação inicial;
- idempotência;
- chaveamento nos dois sentidos;
- caminhos com espaços;
- detecção de ativação simultânea;
- múltiplas instalações conflitantes;
- `--dry-run` sem mutações;
- preservação de alterações em `settings.json`;
- rollback de chaveamento com falha;
- restauração de plugin preexistente;
- status sem instalação.

## Limitações conhecidas

- A suíte automatizada usa mocks. Faça inicialmente `--dry-run` e depois valide com `doctor` na sua versão real do Claude Code e do Nori.
- O formato JSON de `claude plugin list --json` é normalizado defensivamente, mas versões futuras podem introduzir um formato incompatível.
- O Nori mantém parte de seu comportamento em configuração global do Claude Code; outros projetos Nori devem ser considerados antes de uma purga global.
- A mesclagem de listas JSON remove entradas adicionadas pelo Nori usando igualdade estrutural. Uma alteração manual dentro da mesma entrada pode ser preservada como conflito.

## Licença

MIT.
