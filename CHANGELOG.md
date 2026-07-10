# Changelog

## 0.1.1 — 2026-07-10

- ShellCheck linting aplicado em todos os scripts (zero warnings).
- Formatação padronizada com shfmt (`-i 2 -ci`).
- Adicionado `.editorconfig` para consistência entre editores.
- Mensagens de erro do `json_tool.py` agora incluem o comando que falhou.
- Refatorado `cm_other_installed_states`: controle de fluxo com flag em vez de exceção.
- Removida variável não utilizada `existing_state` em `cm_install`.
- Corrigido padrão `A && B || C` substituído por `if/then` em `cm_debug` e `cm_nori_marker`.
- Correção de segurança: `rm` com `${var:?}` para prevenir expansão acidental.
- Onze testes comportamentais (adicionado teste para contexto em erros do json_tool).

## 0.1.0 — 2026-07-10

- Instalação concomitante de Nori `senior-swe` e Superpowers.
- Chaveamento mutuamente exclusivo entre `senior` e `superpowers`.
- Plugin Superpowers limitado ao escopo Claude Code `local`.
- Skillset Nori vazio e tool-owned para neutralização.
- Estado por projeto, lock, dry-run, status humano/JSON e doctor.
- Rollback de melhor esforço.
- Desinstalação com restauração de componentes preexistentes.
- Mesclagem de três vias para preservar alterações em `~/.claude/settings.json`.
- Dez testes comportamentais com mocks.
