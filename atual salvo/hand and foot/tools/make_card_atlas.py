#!/usr/bin/env python3
"""
Gerador de Atlas de Texturas para Cartas - Hand & Foot Canasta (Second Life)

Gera 2 texturas atlas de 1024x1024 (8x4 grade, cada celula 128x256)
contendo todas as 54 faces de cartas (13 ranks x 4 naipes + 2 curingas).
Também gera uma textura de verso de carta.

Uso: python3 tools/make_card_atlas.py
Requer: pip install Pillow
"""

from PIL import Image, ImageDraw, ImageFont
import os, math

# ── Configuração ──────────────────────────────────────────────
ATLAS_W, ATLAS_H = 1024, 1024
COLS, ROWS = 8, 4
CELL_W, CELL_H = ATLAS_W // COLS, ATLAS_H // ROWS  # 128 x 256

RANKS = ['3','4','5','6','7','8','9','10','J','Q','K','A','2']
SUITS = ['♣','♦','♥','♠']
SUIT_COLORS = [(0,0,0), (200,0,0), (200,0,0), (0,0,0)]  # preto, vermelho, vermelho, preto
RANK_NAMES = {'3':'3','4':'4','5':'5','6':'6','7':'7','8':'8','9':'9',
              '10':'10','J':'J','Q':'Q','K':'K','A':'A','2':'2'}

OUT_DIR = 'assets'

# ── Funções auxiliares ────────────────────────────────────────
def get_font(size):
    """Tenta carregar uma fonte TTF bonita; fallback para default."""
    for path in ['/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',
                 '/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf',
                 '/usr/share/fonts/TTF/DejaVuSans-Bold.ttf',
                 '/usr/share/fonts/freefont/FreeSansBold.ttf']:
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()

def draw_card_cell(draw, x0, y0, rank_str, suit_str, color, is_joker=False):
    """Desenha uma carta na celula (x0,y0) do atlas."""
    w, h = CELL_W, CELL_H
    # Fundo branco com borda
    draw.rectangle([x0+2, y0+2, x0+w-3, y0+h-3], fill=(255,255,255), outline=(80,80,80), width=1)

    if is_joker:
        # Curinga: estrela grande central
        font_big = get_font(40)
        font_sm = get_font(14)
        cx, cy = x0 + w//2, y0 + h//2
        draw.text((cx - 12, cy - 24), "★", fill=(200,0,0) if 'Vermelho' in rank_str else (0,0,0), font=font_big)
        draw.text((x0+6, y0+6), "Jk", fill=(200,0,0) if 'Vermelho' in rank_str else (0,0,0), font=font_sm)
        label = "CURINGA" if 'Vermelho' in rank_str else "CURINGA"
        draw.text((x0+6, y0+h-20), label[:3], fill=(200,0,0) if 'Vermelho' in rank_str else (0,0,0), font=font_sm)
        return

    font_rank = get_font(22)
    font_suit_sm = get_font(16)
    font_suit_lg = get_font(48)

    # Canto superior esquerdo: rank + naipe
    draw.text((x0+6, y0+4), rank_str, fill=color, font=font_rank)
    draw.text((x0+6, y0+26), suit_str, fill=color, font=font_suit_sm)

    # Centro: naipe grande
    suit_bbox = font_suit_lg.getbbox(suit_str)
    sw = suit_bbox[2] - suit_bbox[0]
    sh = suit_bbox[3] - suit_bbox[1]
    cx = x0 + (w - sw) // 2
    cy = y0 + (h - sh) // 2 - 10
    draw.text((cx, cy), suit_str, fill=color, font=font_suit_lg)

    # Canto inferior direito (invertido)
    draw.text((x0+w-24, y0+h-28), rank_str, fill=color, font=font_rank)
    draw.text((x0+w-22, y0+h-46), suit_str, fill=color, font=font_suit_sm)


def generate_atlas(atlas_index, cards, filename):
    """Gera um atlas com as cartas especificadas."""
    img = Image.new('RGBA', (ATLAS_W, ATLAS_H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    for i, card in enumerate(cards):
        col = i % COLS
        row = i // COLS
        x0 = col * CELL_W
        y0 = row * CELL_H
        if card is None:
            continue
        if card.get('joker'):
            draw_card_cell(draw, x0, y0, card['rank'], '', card['color'], is_joker=True)
        else:
            draw_card_cell(draw, x0, y0, card['rank'], card['suit'], card['color'])

    filepath = os.path.join(OUT_DIR, filename)
    img.save(filepath, 'PNG')
    print(f"  ✓ {filepath} ({ATLAS_W}x{ATLAS_H})")
    return filepath


def generate_card_back():
    """Gera textura de verso de carta (128x256, será aplicada por repeat)."""
    img = Image.new('RGBA', (CELL_W, CELL_H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Fundo azul escuro com padrão losango
    draw.rectangle([0, 0, CELL_W-1, CELL_H-1], fill=(20, 40, 100))
    draw.rectangle([3, 3, CELL_W-4, CELL_H-4], fill=(30, 60, 140), outline=(180, 160, 60), width=2)

    # Padrão de losango
    for y in range(10, CELL_H-10, 20):
        for x in range(10, CELL_W-10, 20):
            pts = [(x, y-6), (x+6, y), (x, y+6), (x-6, y)]
            draw.polygon(pts, outline=(60, 90, 170), fill=(35, 65, 150))

    # Borda dourada interna
    draw.rectangle([6, 6, CELL_W-7, CELL_H-7], outline=(200, 180, 60), width=1)

    filepath = os.path.join(OUT_DIR, 'card_back.png')
    img.save(filepath, 'PNG')
    print(f"  ✓ {filepath} ({CELL_W}x{CELL_H})")
    return filepath


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    print("Gerando atlas de cartas para Hand & Foot Canasta...\n")

    # Construir lista de 54 faces de carta
    all_faces = []
    for rank in RANKS:
        for si, suit in enumerate(SUITS):
            all_faces.append({
                'rank': rank,
                'suit': suit,
                'color': SUIT_COLORS[si],
                'joker': False
            })

    # 2 curingas (vermelho e preto)
    all_faces.append({'rank': 'Vermelho', 'suit': '', 'color': (200,0,0), 'joker': True})
    all_faces.append({'rank': 'Preto', 'suit': '', 'color': (0,0,0), 'joker': True})

    assert len(all_faces) == 54, f"Esperado 54 faces, obtido {len(all_faces)}"

    # Dividir em 2 atlas (32 + 22)
    atlas1_cards = all_faces[:32]
    atlas2_cards = all_faces[32:]  # 22 cartas + preencher resto com None
    while len(atlas2_cards) < 32:
        atlas2_cards.append(None)

    print("Atlas 1 (cartas 0-31):")
    generate_atlas(1, atlas1_cards, 'cards_atlas_1.png')

    print("Atlas 2 (cartas 32-53):")
    generate_atlas(2, atlas2_cards, 'cards_atlas_2.png')

    print("Verso de carta:")
    generate_card_back()

    # Gerar tabela de mapeamento para LSL
    print("\n" + "="*60)
    print("MAPEAMENTO PARA LSL (faceCode → atlas, col, row, offsets)")
    print("="*60)
    for code in range(54):
        if code < 32:
            atlas = 1
            col = code % 8
            row = code // 8
        else:
            atlas = 2
            col = (code - 32) % 8
            row = (code - 32) // 8
        h_offset = col * 0.125
        v_offset = 1.0 - (row + 1) * 0.25
        h_repeat = 0.125
        v_repeat = 0.25

        # Decodificar face
        if code < 48:
            rank_idx = code // 4
            suit_idx = code % 4
            rank_name = RANKS[rank_idx]
            suit_name = SUITS[suit_idx]
        elif code < 52:
            suit_idx = code - 48
            rank_name = '2'
            suit_name = SUITS[suit_idx]
        else:
            rank_name = 'Joker'
            suit_name = '(Vermelho)' if code == 52 else '(Preto)'

        print(f"  code {code:2d} = {rank_name:>5s}{suit_name:>4s}  →  atlas {atlas}  "
              f"col {col} row {row}  "
              f"offset <{h_offset:.3f}, {v_offset:.3f}>  repeat <{h_repeat:.3f}, {v_repeat:.3f}>")

    print("\n✅ Atlas gerados com sucesso!")
    print(f"   Upload os 3 PNGs em Second Life (L$10 cada).")
    print(f"   Cole os UUIDs no notecard 'HF Config'.")


if __name__ == '__main__':
    main()
