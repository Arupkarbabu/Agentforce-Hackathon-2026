// Simple state management without beta features
const state = {
    promotionName: '',
    chosenProducts: [],
    chosenStores: []
};

const promotionStateManager = {

    setProduct: (product) => {
        let chosenProductsTemp = [...state.chosenProducts];
        const existingIndex = chosenProductsTemp.findIndex(p => p.productId === product.productId);
        if (existingIndex >= 0) {
            chosenProductsTemp[existingIndex] = { ...chosenProductsTemp[existingIndex], ...product };
        } else {
            chosenProductsTemp.push(product);
        }
        state.chosenProducts = chosenProductsTemp;
    },

    removeProduct: (productId) => {
        state.chosenProducts = state.chosenProducts.filter(p => p.productId !== productId);
    },

    updateProducts: (products) => {
        state.chosenProducts = [...products];
    },

    isProductSelected: (productId) => {
        return state.chosenProducts.some(p => p.productId === productId);
    },

    getProductDiscount: (productId) => {
        const product = state.chosenProducts.find(p => p.productId === productId);
        return product ? product.discountPercent : 0;
    },

    getProductCount: () => {
        return state.chosenProducts.length;
    },

    updateStores: (stores) => {
        state.chosenStores = [...stores];
    },

    updatePromotionName: (name) => {
        state.promotionName = name;
    },

    getState: () => state
};

export default promotionStateManager;