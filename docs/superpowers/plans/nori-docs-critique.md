# Critical Revision of Nori Docs — Implementation Plan

**Goal:** Identify and fix structural, factual, consistency, tone, and technical-debt issues across all 34 Nori documentation files.

**Architecture:** Six-dimension evaluation (consistency, duplication, correctness, gaps, tone, tech debt) followed by categorized fixes organized by severity.

**Tech Stack:** Markdown/YAML editing. No code changes. All changes to `.md` files under `/home/marco/.claude/`.

---

## Findings Summary (by dimension, severity-ordered)

---

### DIMENSION 1: CORREÇÃO FACTUAL (CRITICAL)

**F1.1 — Referências a skills inexistentes (QUEBRADO)**

5 referências a arquivos que não existem no filesystem:

| Arquivo | Referencia | Status |
|---------|-----------|--------|
| `agents/paid-nori-knowledge-researcher.md` | `/home/marco/.claude/skills/recall/SKILL.md` | **NÃO EXISTE** |
| `agents/paid-nori-knowledge-researcher.md` | `/home/marco/.claude/skills/memorize/SKILL.md` | **NÃO EXISTE** |
| `agents/nori-initial-documenter.md` | `/home/marco/.claude/skills/nori-sync-docs/SKILL.md` | **NÃO EXISTE** |
| `agents/nori-change-documenter.md` | `/home/marco/.claude/skills/nori-sync-docs/SKILL.md` | **NÃO EXISTE** |
| `skills/test-driven-development/SKILL.md` | subagente `nori-task-runner` | **NÃO EXISTE** |
| `skills/finishing-a-development-branch/SKILL.md` | skill `test-scenario-hygiene` | **NÃO EXISTE** |

**Impacto:** O agente `paid-nori-knowledge-researcher` simplesmente não funciona — suas instruções obrigam (`<required>`) o uso de `recall` e `memorize`, que não existem. Os documenters tentam acessar `nori-sync-docs` que também não existe.

**F1.2 — Nome de arquivo vs YAML name (INCONSISTENTE)**

- `paid-nori-knowledge-researcher.md` tem YAML `name: nori-knowledge-researcher` (sem "paid-")
- `nori-info/SKILL.md` tem YAML `name: Nori Skillsets` (diretório é `nori-info`, nome YAML é "Nori Skillsets")

**Impacto:** Se o sistema resolve skills/agents por nome de diretório/arquivo, essas referências quebram. Se resolve por YAML name, o nome `Nori Skillsets` (com espaço) pode causar problemas em path resolution.

**F1.3 — Frase truncada no CLAUDE.md**

Copilot mode: `Copilot mode should behave identically to full-send mode, just on your` — a frase corta no meio.

**F1.4 — API key em plaintext no settings.json**

`ANTHROPIC_AUTH_TOKEN` está visível em `/home/marco/.claude/settings.json`. Este arquivo é versionado? Precisa verificar `.gitignore`.

---

### DIMENSION 2: CONSISTÊNCIA ESTRUTURAL (HIGH)

**F2.1 — Frontmatter YAML inconsistente**

- Skills: todos têm `name:` e `description:` (exceto `nori-info` que tem nome divergente)
- Agents: todos têm `name:`, `description:`, `tools:`, `model: inherit` (alguns têm `color:`)
- Noridocs: **nenhum** YAML frontmatter — começam direto com `# Noridoc: [name]`
- Commands: YAML com `description:` e `allowed-tools:`

**F2.2 — Heading hierarchy inconsistente**

- `using-skills/SKILL.md` usa apenas H1 (`#`) para TODAS as seções — 3 headings no mesmo nível, sem hierarquia
- Os outros skills usam H1 (`#`) para título e H2 (`##`) para seções
- Agents usam H2 (`##`) como heading principal, H3 (`###`) para subseções

**F2.3 — `<required>` vs `*CRITICAL*` vs `<critical>` sem padrão**

- `systematic-debugging/SKILL.md` usa `<critical>` (minúsculo) dentro de `<required>`
- A maioria usa `*CRITICAL*` (negrito) como texto dentro de `<required>`
- Nenhum padrão documentado para quando usar cada um

**F2.4 — Formato de checklist inconsistente**

- Maioria usa `1. Do X` numerado dentro de `<required>`
- `systematic-debugging` usa bullets `- <critical> Build a replication. </critical>`
- `creating-debug-tests-and-iterating` pula do passo 3 para o 5 (sem passo 4)
- `nori-code-reviewer` tem passo 3 duplicado (duas vezes)

**F2.5 — "Announce at start" inconsistente**

Apenas 4 skills têm instrução de anúncio: brainstorming, building-ui-ux, receiving-code-review, updating-noridocs. Os outros 14 não mencionam como se anunciar.

---

### DIMENSION 3: DUPLICAÇÃO E REDUNDÂNCIA (HIGH)

**F3.1 — Bloco "CRITICAL: YOUR ONLY JOB IS TO DOCUMENT..." duplicado 5x**

Idêntico ou quase idêntico em:
- `nori-initial-documenter.md`
- `nori-change-documenter.md`
- `nori-codebase-locator.md`
- `nori-codebase-analyzer.md`
- `nori-codebase-pattern-finder.md`

**Estimativa de desperdício:** ~15-20 linhas por arquivo = ~85 linhas duplicadas.

**F3.2 — "REMEMBER: You are a documentarian, not a critic" duplicado 5x**

Mesmos 5 arquivos, cada um com variação do mesmo parágrafo final. ~5-8 linhas cada = ~30 linhas.

**F3.3 — Seção "What NOT to Do" duplicada 4x**

`nori-initial-documenter`, `nori-change-documenter`, `nori-codebase-analyzer`, `nori-codebase-pattern-finder` têm listas quase idênticas de proibições. ~15 linhas cada = ~60 linhas.

**F3.4 — Output Format de noridoc duplicado 3x**

O template de noridoc aparece em:
1. `nori-initial-documenter.md` (Output Format)
2. `nori-change-documenter.md` (Output Format)
3. `updating-noridocs/SKILL.md` (Noridocs Format)

**F3.5 — CLAUDE.md duplica descrições de skills**

CLAUDE.md lista todos os 18 skills com suas descrições, que são cópias do YAML `description:` de cada SKILL.md. Qualquer mudança de descrição precisa ser feita em dois lugares.

**F3.6 — Output Format de coding tasks duplicado**

O template de output para coding tasks é quase idêntico entre `nori-codebase-analyzer.md` e `paid-nori-knowledge-researcher.md`.

---

### DIMENSION 4: TOM E VOZ (MEDIUM)

**F4.1 — Tom casual/jocoso em agentes (conflito com CLAUDE.md)**

CLAUDE.md estabelece tom direto, não-deferente e profissional. Três agentes quebram isso:
- `nori-web-search-researcher.md`: "you can get your money back! (Not really...)"
- `nori-codebase-pattern-finder.md`: "you can use your handy dandy Grep, Glob, and LS tools"
- `nori-codebase-locator.md` e `nori-codebase-pattern-finder.md`: "I believe in you, you are a smart cookie :)"

**F4.2 — "Documentarian, not a critic" vs CLAUDE.md tone**

Os 5 agentes de documentação instruem o AI a NÃO ser crítico ("DO NOT critique", "DO NOT suggest improvements"). Mas o CLAUDE.md explicitamente instrui: "Flag bad ideas, unreasonable expectations, and mistakes" e "If you disagree... PUSH BACK."

**F4.3 — Marketing-speak em descrições YAML**

`nori-web-search-researcher.md` description é um parágrafo de marketing: "Do you find yourself desiring information that you don't quite feel well-trained (confident) on?" — não é uma descrição funcional do agente.

---

### DIMENSION 5: GAPS DE CONTEÚDO (MEDIUM)

**F5.1 — Skills/agents referenciados mas inexistentes**

Já coberto em F1.1. Adicionalmente:
- Nenhum skill de onboarding/primeiros passos
- Nenhum skill de configuração do Nori
- Nenhuma documentação sobre a relação Nori vs Superpowers

**F5.2 — `handle-large-tasks/SKILL.md` é mínimo demais**

26 linhas — o menor de todos os skills. É praticamente só um checklist sem orientação real.

**F5.3 — `nori-info/SKILL.md` é só links**

25 linhas — 3 URLs e nenhum conteúdo real. Devia ser a documentação central sobre Nori.

**F5.4 — `nori-code-reviewer.md` é fino demais**

32 linhas para algo tão crítico quanto code review. Comparado com `nori-codebase-pattern-finder.md` (241 linhas), a disparidade é gritante.

**F5.5 — Memory system vazio**

`/home/marco/.claude/projects/-mnt-c-projects-claude-mode/memory/` existe mas está vazio. Não há MEMORY.md index. O sistema de memória do Claude Code está documentado no system prompt mas nunca foi inicializado para este projeto.

**F5.6 — Diretório `references/` não existe**

`/home/marco/.claude/references/` é referenciado por `using-superpowers` mas não existe.

**F5.7 — Sem explicação de skills vs agents vs commands**

Nenhum documento explica quando usar um skill (invocado via `Skill` tool), um agent (invocado via `Agent` tool com `subagent_type`), ou um command (`/nori-init-docs`). A relação entre esses três conceitos não é documentada.

---

### DIMENSION 6: DÍVIDA TÉCNICA (LOW-MEDIUM)

**F6.1 — Numeração quebrada em checklists**

- `nori-code-reviewer.md`: passo 3 duplicado ("3. Check if tests..." e "3. Check for bugs")
- `creating-debug-tests-and-iterating/SKILL.md`: checklist pula do 3 para o 5
- `paid-nori-knowledge-researcher.md`: Phase 1 checklist pula do passo 6 para o 8

**F6.2 — URLs hardcoded com commit hash específico**

`creating-skills/SKILL.md` referencia:
```
https://raw.githubusercontent.com/tilework-tech/nori-skillsets/96012bcfcd9482b248debed7b9a7fc7c345f76e1/...
```
Estes URLs vão quebrar quando o repositório avançar.

**F6.3 — Typo em agent**

`nori-change-documenter.md` seção 2: "Document Chnages" (deveria ser "Changes")

**F6.4 — Tool naming inconsistency**

- CLAUDE.md diz "Task tool" / "TodoWrite"
- Skills dizem "Task tool", "Task(subagent_type: ...)", "Task tool using nori-*"
- O tool real no harness atual é `Agent` e `TaskCreate`

**F6.5 — `docs/docs.md` admite estar desatualizado**

"These are reference documents for understanding design intent but may not reflect the current implementation exactly." — se é documentação, precisa estar correta ou ser removida.

---

## PRIORIZAÇÃO

### Blocker (quebra funcionalidade)
1. F1.1 — Criar stubs para `recall/SKILL.md`, `memorize/SKILL.md`, `nori-sync-docs/SKILL.md` OU remover referências
2. F1.2 — Alinhar `nori-info/SKILL.md` name YAML com diretório; decidir padrão para `paid-nori-knowledge-researcher`
3. F1.3 — Corrigir frase truncada no CLAUDE.md

### High (causa confusão ou comportamento errado)
4. F2.2 — Normalizar heading hierarchy em `using-skills/SKILL.md`
5. F2.4 — Corrigir numeração quebrada nos checklists (F6.1)
6. F3.1-F3.3 — Extrair blocos duplicados dos agentes para um shared include OU aceitar a duplicação
7. F4.1 — Remover tom casual/jocoso de agentes
8. F6.3 — Corrigir "Chnages" → "Changes"

### Medium (melhoria de qualidade)
9. F2.1 — Decidir se noridocs devem ter YAML frontmatter
10. F2.5 — Adicionar "Announce at start" aos skills que não têm
11. F3.4 — Consolidar template de noridoc em um só lugar
12. F3.5 — Remover duplicação de descrições do CLAUDE.md (substituir por referência)
13. F4.2 — Resolver conflito "documentarian vs critic"
14. F5.2 — Expandir `handle-large-tasks/SKILL.md`
15. F5.3 — Expandir `nori-info/SKILL.md`
16. F5.4 — Expandir `nori-code-reviewer.md`
17. F5.5 — Inicializar MEMORY.md
18. F5.7 — Documentar skills vs agents vs commands

### Low (nice to have)
19. F1.4 — Remover API key do settings.json (se versionado)
20. F2.3 — Documentar padrão para `<required>`/`<critical>`/`*CRITICAL*`
21. F3.6 — Consolidar output formats de coding tasks
22. F4.3 — Reescrever descriptions YAML em tom funcional
23. F5.1 — Criar skill de onboarding
24. F5.6 — Criar diretório `references/`
25. F6.2 — Substituir URLs hardcoded por referências relativas ou tags
26. F6.4 — Alinhar nomenclatura de tools com o harness real
27. F6.5 — Atualizar ou remover `docs/docs.md`

---

## ABORDAGEM DE IMPLEMENTAÇÃO

### Fase 1: Correções críticas (Blocker + High)
- Criar stubs para os 3 skills faltantes (ou remover referências se preferir)
- Corrigir YAML names
- Corrigir frase truncada no CLAUDE.md
- Corrigir numeração quebrada
- Normalizar headings no using-skills
- Extrair blocos duplicados dos agentes (manter em cada arquivo mas padronizar)

### Fase 2: Qualidade (Medium)
- Consolidar template noridoc
- Adicionar announce at start
- Expandir skills finos
- Inicializar memory system
- Documentar skills vs agents vs commands

### Fase 3: Polish (Low)
- Limpeza de URLs, typos, nomenclatura
- Criar onboarding e references

---

**Testing Details:** Como isto é uma mudança de documentação, a validação será feita por:
1. Verificar que todos os paths referenciados em docs existem no filesystem
2. Re-ler cada arquivo modificado para confirmar consistência
3. Verificar `git diff --stat` para confirmar que todos os arquivos esperados foram alterados

**Implementation Details:**
- ~27 mudanças em ~20 arquivos
- Nenhum código de produção afetado
- Alterações puramente textuais/markdown
- A maioria das mudanças são edições pontuais, não rewrites

**Questions:**
1. Para F1.1 (skills inexistentes): criar stubs mínimos ou remover as referências?
2. Para F3.1-F3.3 (duplicação em agentes): extrair para um shared include (requer suporte do harness) ou manter duplicação mas padronizar o texto?
3. Para F1.2: renomear `paid-nori-knowledge-researcher.md` para `nori-knowledge-researcher.md` ou ajustar o YAML name?
4. A API key no settings.json (F1.4) deve ser removida? O arquivo é versionado?
---
