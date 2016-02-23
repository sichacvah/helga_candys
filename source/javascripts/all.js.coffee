#= require product


document.addEventListener("DOMContentLoaded", ->
  product = Elm.embed(Elm.Product, 
                   document.getElementById('product-cart'), 
                   {initParams: null})

  cart = Elm.embed(Elm.Cart, document.getElementById('cart'), {initParams: null})



  productsToCart = document.querySelectorAll ".product-to-cart"
  console.log productsToCart

  for productToCart in productsToCart
    productToCart.addEventListener "click", (e)->
      e.preventDefault()
      productId = this.dataset.productId
      left = 0
      top =  window.pageYOffset
      product.ports.initParams.send(
        top: top,
        left: left,
        productId: parseInt(productId)
      )
      product.ports.addToCart.subscribe( (items)->
        cart.ports.addToCart(items)
      )
)



