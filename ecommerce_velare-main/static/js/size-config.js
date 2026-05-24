window.SizeConfig = {
    categories: {
        'dresses': {
            label: 'Dresses',
            sizes: ['XS', 'S', 'M', 'L', 'XL', 'XXL'],
            type: 'clothing'
        },
        'skirts': {
            label: 'Skirts',
            sizes: ['XS', 'S', 'M', 'L', 'XL', 'XXL'],
            type: 'clothing'
        },
        'tops': {
            label: 'Tops',
            sizes: ['XS', 'S', 'M', 'L', 'XL', 'XXL'],
            type: 'clothing'
        },
        'blouses': {
            label: 'Blouses',
            sizes: ['XS', 'S', 'M', 'L', 'XL', 'XXL'],
            type: 'clothing'
        },
        'activewear': {
            label: 'Activewear',
            sizes: ['XS', 'S', 'M', 'L', 'XL', 'XXL'],
            type: 'clothing'
        },
        'yoga-pants': {
            label: 'Yoga Pants',
            sizes: ['XS', 'S', 'M', 'L', 'XL', 'XXL'],
            type: 'clothing'
        },
        'lingerie': {
            label: 'Lingerie',
            sizes: ['XS', 'S', 'M', 'L', 'XL'],
            type: 'clothing'
        },
        'sleepwear': {
            label: 'Sleepwear',
            sizes: ['XS', 'S', 'M', 'L', 'XL', 'XXL'],
            type: 'clothing'
        },
        'jackets': {
            label: 'Jackets',
            sizes: ['XS', 'S', 'M', 'L', 'XL', 'XXL'],
            type: 'clothing'
        },
        'coats': {
            label: 'Coats',
            sizes: ['XS', 'S', 'M', 'L', 'XL', 'XXL'],
            type: 'clothing'
        },
        'shoes': {
            label: 'Shoes',
            sizes: ['5', '6', '6.5', '7', '7.5', '8', '8.5', '9', '9.5', '10', '10.5', '11', '11.5', '12'],
            type: 'shoes'
        },
        'accessories': {
            label: 'Accessories',
            sizes: ['One Size'],
            type: 'accessories'
        }
    },

    getSizesForCategory(category) {
        if (this.categories[category]) {
            return this.categories[category].sizes;
        }
        return ['One Size'];
    },

    getCategoryLabel(category) {
        if (this.categories[category]) {
            return this.categories[category].label;
        }
        return category;
    },

    getCategoryType(category) {
        if (this.categories[category]) {
            return this.categories[category].type;
        }
        return 'clothing';
    }
};
