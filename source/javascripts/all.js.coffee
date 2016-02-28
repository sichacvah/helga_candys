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
  year = new Date().getFullYear()
  if window.Stripe
    Stripe.setPublishableKey "pk_test_KQLInParCU24art9kd7uKK25"

  cartItems = parseCartItems localStorage.getItem('cartItems')

  cart = Elm.embed(Elm.Cart, document.getElementById('cart'), {addToCart: null, recieveFromStripe: null })

  if cartItems
    cart.ports.addToCart.send(cartItems)

  cart.ports.saveToStorage.subscribe( (items)->
   localStorage.setItem('cartItems', stringifyCartItems(items))
  )

  cart.ports.orderCreated.subscribe( (created) ->
    delete localStorage.cartItems
  )

  cart.ports.sendToStripe.subscribe( (card)->

    stripeCard = 
      number: card.cardNumber
      cvc: card.cvc
      exp_year: card.expYear
      exp_month: card.expMonth
    Stripe.card.createToken(stripeCard, (status, response) ->
      if (response.error) 
        cart.ports.recieveFromStripe.send({cardToken: "", error: response.error.code})
      else 
        cart.ports.recieveFromStripe.send({cardToken: response.id, error: null})
    )
  )

  productsToCart = document.querySelectorAll ".product-to-cart"

  if productsToCart.length > 0
    for productToCart in productsToCart
      productToCart.addEventListener "click", (e)->
        delete product if product
        product = Elm.embed(Elm.Product, 
                     document.getElementById('product-cart'), 
                     {initParams: null})

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
          console.log(items)
          cart.ports.addToCart.send(items)
        )
)



