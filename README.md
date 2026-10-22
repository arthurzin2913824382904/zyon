# Zyon Hub

Interface refeita do zero para a source de **Illegal Soccer** fornecida pelo autor.
Tema preto e roxo, texto branco, abas laterais, ícones vetoriais, janela arrastável,
botões de minimizar/descarregar e suporte a mouse e toque.

## Arquivos

- `zyon-hub.lua`: script completo, com o núcleo original e a nova interface embutida.
- `zyon-ui-preview.lua`: prévia independente da interface. Pode ser colocada em um
  **LocalScript** em `StarterPlayer > StarterPlayerScripts` no Roblox Studio. Não
  carrega módulos do jogo nem executa automações. Os controles de gameplay ficam
  sinalizados como pendentes; navegação, slider e janela podem ser experimentados.
- `src/ZyonUI.luau`: implementação da interface, sem biblioteca externa.
- `src/zyon-core.luau`: núcleo e integração dos controles. O núcleo continua
  dependendo dos módulos específicos de Illegal Soccer presentes na source enviada.

**RightShift** mostra ou oculta a janela. Arraste pelo cabeçalho para mover.
O botão **×** do script completo chama o descarregamento da source.

## Abas e estado das funções

| Aba | Controles | Integração |
| --- | --- | --- |
| Offense · faca | Auto Shooting | Usa a assistência de mira e liberação da source. O jogador ainda inicia o chute. |
| Offense · faca | Auto Passing | Pendente: não havia implementação na source. |
| Defense · escudo | Auto GK; Close-range Rush; High-ball Jumps; Jump Then Dive; Lob / Back Recovery | Ligados aos controles originais do goleiro. Auto GK inicia desligado. |
| Defense · escudo | Dive Direction; Position Assist; Pre-shot Coverage; Position Mode; Manual Movement First | Ligados às configurações originais, preservando as reinicializações do planejador. |
| Defense · escudo | Status; contadores de solicitações/saltos/mergulhos/rush; diagnóstico | Lê o estado original e permite imprimir `AutoGKDebug()` no console. |
| Misc · engrenagem | Infinite Stamina; Full Speed Charge; Ball Magnetic; Auto Sprint | Pendentes: não havia implementação dessas funções na source. |
| Misc · engrenagem | Ball Magnetic Range | Slider de 1 a 50 studs, padrão 12. Guarda a seleção da sessão; só afetará a bola quando Ball Magnetic for implementado. |

Controles pendentes permanecem desligados. Os testes locais **não validam**
o comportamento dentro de Illegal Soccer: Roblox e os módulos do jogo não estão
disponíveis nesta máquina.

## Desenvolvimento e testes

Edite os arquivos de `src/` e gere novamente os dois scripts:

```sh
python3 tools/build.py
```

Os testes usam o CLI oficial de Luau e mocks de Roblox para executar os callbacks
reais da interface. Também verificam os adaptadores extraídos do núcleo e compilam
os scripts completos. Com `luau` e `luau-compile` no PATH:

```sh
python3 tools/test.py
```

Alternativamente, defina `LUAU_BIN=/caminho/para/luau`. Validação nesta tarefa:
Luau 0.727, **19 testes de interface e 6 verificações de integração**.

Para conectar uma função nova, forneça um adaptador na tabela `features` da
integração do núcleo. O método `Set` deve executar a alteração real e devolver
`false` se ela falhar. `Get` deve consultar o estado real como um booleano.
Também é possível registrar um adaptador durante a sessão com
`ZyonHub.BindFeature(chave, { Get = getter, Set = setter })` no mesmo ambiente
global da source. As chaves pendentes são `autoPassing`, `infiniteStamina`,
`fullSpeedCharge`, `ballMagnetic` e `autoSprint`.

`ZyonHub.GetState().magneticRange` expõe o valor escolhido no slider. Um módulo
que precise reagir imediatamente ao slider pode usar o callback `onRangeChanged`
da interface. As seleções das novas opções ficam apenas na sessão; os arquivos
de configuração antigos não são importados automaticamente.
