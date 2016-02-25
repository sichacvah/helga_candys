#= require product
#= require cart

parseCartItems = (cartItems) ->
  if cartItems && cartItems.length > 0
    JSON.parse(cartItems)
  else
    null


stringifyCartItems = (items) ->
  if items
    JSON.stringify items
  else
    ""

document.addEventListener("DOMContentLoaded", ->
  product = Elm.embed(Elm.Product, 
                   document.getElementById('product-cart'), 
                   {initParams: null})

  cartItems = parseCartItems localStorage.getItem('cartItems')

  cart = Elm.embed(Elm.Cart, document.getElementById('cart'), {addToCart: null})
  if cartItems
    cart.ports.addToCart.send(cartItems)
  cart.ports.saveToStorage.subscribe( (items)->
    localStorage.setItem('cartItems', stringifyCartItems(items))
  )

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
        cart.ports.addToCart.send(items)
      )
)



