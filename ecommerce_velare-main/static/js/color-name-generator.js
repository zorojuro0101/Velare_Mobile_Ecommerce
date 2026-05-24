window.ColorNameGenerator = {
    colorDatabase: {
        'FF0000': ['Red', 'Crimson', 'Scarlet', 'Ruby', 'Vermillion'],
        'FF1493': ['Deep Pink', 'Hot Pink', 'Magenta', 'Fuchsia'],
        'FFB6C1': ['Light Pink', 'Rose', 'Blush', 'Coral Pink'],
        'FFC0CB': ['Pink', 'Pale Pink', 'Soft Pink'],
        'FF69B4': ['Hot Pink', 'Vibrant Pink', 'Neon Pink'],
        'FF8C00': ['Dark Orange', 'Burnt Orange', 'Tangerine'],
        'FFA500': ['Orange', 'Bright Orange', 'Pumpkin'],
        'FFD700': ['Gold', 'Golden', 'Amber'],
        'FFFF00': ['Yellow', 'Bright Yellow', 'Lemon'],
        'FFFFE0': ['Light Yellow', 'Pale Yellow', 'Cream'],
        '00FF00': ['Lime', 'Bright Green', 'Neon Green'],
        '008000': ['Green', 'Forest Green', 'Dark Green'],
        '90EE90': ['Light Green', 'Mint Green', 'Pale Green'],
        '00CED1': ['Dark Turquoise', 'Turquoise', 'Cyan'],
        '00BFFF': ['Deep Sky Blue', 'Sky Blue', 'Azure'],
        '0000FF': ['Blue', 'Royal Blue', 'Cobalt'],
        '4169E1': ['Royal Blue', 'Cornflower Blue', 'Slate Blue'],
        '1E90FF': ['Dodger Blue', 'Bright Blue', 'Ocean Blue'],
        '87CEEB': ['Sky Blue', 'Light Blue', 'Powder Blue'],
        'ADD8E6': ['Light Blue', 'Pale Blue', 'Baby Blue'],
        '800080': ['Purple', 'Violet', 'Indigo'],
        '9370DB': ['Medium Purple', 'Lavender Purple', 'Lilac'],
        'DDA0DD': ['Plum', 'Mauve', 'Orchid'],
        'EE82EE': ['Violet', 'Bright Purple', 'Periwinkle'],
        'FFB6C1': ['Light Pink', 'Rose', 'Blush'],
        'A52A2A': ['Brown', 'Chocolate', 'Chestnut'],
        '8B4513': ['Saddle Brown', 'Tan Brown', 'Burnt Sienna'],
        'D2B48C': ['Tan', 'Beige', 'Khaki'],
        'F5DEB3': ['Wheat', 'Cream', 'Ivory'],
        'FFFFFF': ['White', 'Pure White', 'Snow'],
        'F5F5F5': ['White Smoke', 'Off White', 'Ghost White'],
        'D3D3D3': ['Light Gray', 'Silver', 'Ash'],
        '808080': ['Gray', 'Grey', 'Slate'],
        '404040': ['Dark Gray', 'Charcoal', 'Graphite'],
        '000000': ['Black', 'Jet Black', 'Ebony'],
        '8B0000': ['Dark Red', 'Maroon', 'Burgundy'],
        'CD5C5C': ['Indian Red', 'Salmon', 'Coral'],
        'F08080': ['Light Coral', 'Salmon Pink', 'Peach'],
        '20B2AA': ['Light Sea Green', 'Teal', 'Seafoam'],
        '3CB371': ['Medium Sea Green', 'Sea Green', 'Jade'],
        '2F4F4F': ['Dark Slate Gray', 'Charcoal Green', 'Deep Teal'],
        'FF4500': ['Orange Red', 'Red Orange', 'Rust'],
        'FF6347': ['Tomato', 'Coral Red', 'Sunset'],
        'FF7F50': ['Coral', 'Peach', 'Salmon'],
        'DAA520': ['Goldenrod', 'Golden Brown', 'Mustard'],
        'B8860B': ['Dark Goldenrod', 'Bronze', 'Copper'],
        'DC143C': ['Crimson', 'Deep Red', 'Wine'],
        'C71585': ['Medium Violet Red', 'Magenta Red', 'Berry'],
        '4B0082': ['Indigo', 'Deep Purple', 'Navy Purple'],
        '191970': ['Midnight Blue', 'Navy', 'Deep Navy'],
        '00008B': ['Dark Blue', 'Navy Blue', 'Deep Blue'],
        '0000CD': ['Medium Blue', 'Bright Blue', 'Strong Blue'],
        '6495ED': ['Cornflower Blue', 'Periwinkle', 'Soft Blue'],
        'B0E0E6': ['Powder Blue', 'Pale Blue', 'Misty Blue'],
        'F0FFFF': ['Azure', 'Ice Blue', 'Crystal'],
        'F0F8FF': ['Alice Blue', 'Ghost Blue', 'Whisper Blue'],
        'E0FFFF': ['Light Cyan', 'Pale Cyan', 'Mint'],
        'AFEEEE': ['Pale Turquoise', 'Light Turquoise', 'Aqua'],
        '40E0D0': ['Turquoise', 'Bright Turquoise', 'Aquamarine'],
        '48D1CC': ['Medium Turquoise', 'Cyan', 'Aqua Blue'],
        '00FA9A': ['Medium Spring Green', 'Spring Green', 'Emerald'],
        '00FF7F': ['Spring Green', 'Bright Green', 'Neon Green'],
        '7FFF00': ['Chartreuse', 'Lime Green', 'Yellow Green'],
        'ADFF2F': ['Green Yellow', 'Yellow Green', 'Lime'],
        '9ACD32': ['Yellow Green', 'Olive Green', 'Sage'],
        '6B8E23': ['Olive Drab', 'Khaki Green', 'Moss'],
        '556B2F': ['Dark Olive Green', 'Olive', 'Forest'],
        '8FBC8F': ['Dark Sea Green', 'Sage Green', 'Muted Green'],
        '32CD32': ['Lime Green', 'Bright Green', 'Vibrant Green'],
        'FFE4B5': ['Moccasin', 'Peach', 'Apricot'],
        'FFDEAD': ['Navajo White', 'Tan', 'Beige'],
        'FFE4C4': ['Bisque', 'Cream', 'Vanilla'],
        'FFEFD5': ['Papaya Whip', 'Pale Peach', 'Cream'],
        'FFF8DC': ['Cornsilk', 'Pale Yellow', 'Cream'],
        'FFFACD': ['Lemon Chiffon', 'Pale Yellow', 'Soft Yellow'],
        'FFFAF0': ['Floral White', 'Off White', 'Cream'],
        'FFFFF0': ['Ivory', 'Cream White', 'Off White'],
        'F5FFFA': ['Mint Cream', 'Pale Mint', 'Whisper Green'],
        'F0FFF0': ['Honeydew', 'Pale Green', 'Mint'],
        'F5F5DC': ['Beige', 'Cream', 'Tan'],
        'FFF0F5': ['Lavender Blush', 'Pale Pink', 'Whisper Pink'],
        'FFE4E1': ['Misty Rose', 'Pale Pink', 'Blush'],
        'F0F8FF': ['Alice Blue', 'Pale Blue', 'Whisper Blue'],
        'E6E6FA': ['Lavender', 'Pale Purple', 'Soft Purple'],
        'F8F8FF': ['Ghost White', 'Off White', 'Pale White'],
        'FAFAD2': ['Light Goldenrod Yellow', 'Pale Yellow', 'Cream'],
        'D3D3D3': ['Light Gray', 'Silver', 'Pale Gray'],
        'A9A9A9': ['Dark Gray', 'Slate Gray', 'Ash Gray'],
        '696969': ['Dim Gray', 'Dark Gray', 'Charcoal Gray'],
        '778899': ['Light Slate Gray', 'Slate', 'Blue Gray'],
        '708090': ['Slate Gray', 'Blue Gray', 'Steel Gray'],
    },

    hexToRgb(hex) {
        const result = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex);
        return result ? {
            r: parseInt(result[1], 16),
            g: parseInt(result[2], 16),
            b: parseInt(result[3], 16)
        } : null;
    },

    rgbToHex(r, g, b) {
        return "#" + ((1 << 24) + (r << 16) + (g << 8) + b).toString(16).slice(1).toUpperCase();
    },

    getDistance(rgb1, rgb2) {
        const dr = rgb1.r - rgb2.r;
        const dg = rgb1.g - rgb2.g;
        const db = rgb1.b - rgb2.b;
        return Math.sqrt(dr * dr + dg * dg + db * db);
    },

    getColorName(hexColor) {
        const cleanHex = hexColor.replace('#', '').toUpperCase();
        
        if (this.colorDatabase[cleanHex]) {
            const names = this.colorDatabase[cleanHex];
            return names[Math.floor(Math.random() * names.length)];
        }

        const inputRgb = this.hexToRgb('#' + cleanHex);
        if (!inputRgb) return 'Custom Color';

        let closestColor = null;
        let minDistance = Infinity;

        for (const [hex, names] of Object.entries(this.colorDatabase)) {
            const dbRgb = this.hexToRgb('#' + hex);
            const distance = this.getDistance(inputRgb, dbRgb);

            if (distance < minDistance) {
                minDistance = distance;
                closestColor = names;
            }
        }

        if (closestColor) {
            return closestColor[Math.floor(Math.random() * closestColor.length)];
        }

        return 'Custom Color';
    }
};
