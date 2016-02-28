module Cart (..) where

import Html exposing (..)
import Html.Events exposing (..)
import Http
import Dict
import StartApp
import Effects exposing (Effects, Never)
import Html.Attributes exposing (..)
import Task exposing (Task, andThen)
import Json.Decode exposing ((:=))
import Json.Decode as Decode
import Json.Encode as Encode
import Debug
import String
import Regex


app =
    StartApp.start
        { init = init
        , update = update
        , view = view
        , inputs = [ toCartInput, fromStripe ]
        }


main =
    app.html


port tasks : Signal (Task.Task Never ())
port tasks =
    app.tasks


toAction item =
    case item of
        Nothing ->
            NoOp

        Just cartItems ->
            AddToCart cartItems


toCartInput : Signal Action
toCartInput =
    Signal.map toAction addToCart


port addToCart : Signal (Maybe.Maybe (List Variant))
port saveToStorage : Signal (List Variant)
port saveToStorage =
    saveToStorageMailbox.signal


port sendToStripe : Signal Card
port sendToStripe =
    sendToStripeMailbox.signal


port orderCreated : Signal Bool
port orderCreated =
    orderCreatedMailbox.signal


orderCreatedMailbox : Signal.Mailbox Bool
orderCreatedMailbox =
    Signal.mailbox False


type alias CardResponse =
    { error : Maybe String
    , cardToken : String
    }


port recieveFromStripe : Signal (Maybe CardResponse)
fromStripe : Signal Action
fromStripe =
    let
        toStripeAction res =
            case res of
                Nothing ->
                    NoOp

                Just response ->
                    case response.error of
                        Nothing ->
                            ResponseFromStripe (Ok response.cardToken)

                        Just err ->
                            ResponseFromStripe (Err err)
    in
        Signal.map toStripeAction recieveFromStripe


sendToStripeMailbox : Signal.Mailbox Card
sendToStripeMailbox =
    Signal.mailbox (Card "" "" "" "")


saveToStorageMailbox : Signal.Mailbox (List Variant)
saveToStorageMailbox =
    Signal.mailbox []


toStorage : List Variant -> Effects Action
toStorage variants =
    Signal.send saveToStorageMailbox.address variants
        |> Task.map (\_ -> NoOp)
        |> Effects.task


toOrderCreated : Bool -> Effects Action
toOrderCreated isCreated =
    Signal.send orderCreatedMailbox.address isCreated
        |> Task.map (\_ -> NoOp)
        |> Effects.task


toStripe : Card -> Effects Action
toStripe card =
    Signal.send sendToStripeMailbox.address card
        |> Task.map (\_ -> NoOp)
        |> Effects.task



-- MODEL


type alias Variant =
    { id : Int
    , name : String
    , description : String
    , price : Float
    , imageUrl : String
    , count : Int
    , min : Int
    }


type alias Card =
    { cardNumber : String
    , cvc : String
    , expMonth : String
    , expYear : String
    }


type alias Model =
    { email : String
    , name : String
    , variants : List Variant
    , isShowed : Bool
    , viewType : ViewType
    , showError : Bool
    , card : Card
    , error : String
    }


initModel : Model
initModel =
    Model "" "" [] False CartView False (Card "" "" "" "") ""


init : ( Model, Effects.Effects Action )
init =
    ( initModel, Effects.none )



-- ACTION


type Action
    = NoOp
    | AddToCart (List Variant)
    | Toggle
    | ShowCheckout
    | ShowCart
    | DeleteFromCart Int
    | ChangeCount Int Int
    | CardNumber String
    | CardVerification String
    | CardExpire String
    | Name String
    | Email String
    | Checkout
    | ResponseFromStripe (Result String String)
    | RecievePaymentResponse (Result Http.Error String)


type ViewType
    = CartView
    | CheckoutView


errorMsg : Dict.Dict String String
errorMsg =
    Dict.fromList
        [ ( "invalid_number", "Неправильный номер карты" )
        , ( "invalid_expiry_year", "Неверный год окончания срока действия карты" )
        , ( "invalid_expiry_month", "Неверный месяц окончания срока действия карты" )
        , ( "invalid_cvc", "Неправильный CVC" )
        ]


update : Action -> Model -> ( Model, Effects.Effects Action )
update action model =
    let
        card = model.card
    in
        case action of
            CardNumber n ->
                ( { model | card = { card | cardNumber = n } }, Effects.none )

            CardVerification v ->
                ( { model | card = { card | cvc = v } }, Effects.none )

            CardExpire exp ->
                let
                    expArr = String.split "/" (Debug.log "EXP => " exp)

                    getYear arr = Maybe.withDefault "" (List.head arr)

                    changeCard m y = { card | expMonth = m, expYear = y }
                in
                    case expArr of
                        hd :: [] ->
                            if (String.length card.expYear) == 0 && (String.length card.expMonth) /= 1 then
                                ( { model | card = changeCard (String.left 1 hd) "" }, Effects.none )
                            else
                                ( { model | card = changeCard hd "" }, Effects.none )

                        hd :: tl ->
                            if (String.length card.expYear) > 0 && (String.length (getYear tl)) == 0 then
                                ( { model | card = changeCard (String.left 1 hd) "" }, Effects.none )
                            else
                                ( { model | card = changeCard hd (getYear tl) }, Effects.none )

                        _ ->
                            ( model, Effects.none )

            NoOp ->
                ( model, Effects.none )

            AddToCart newVariants ->
                let
                    variants = (addVariants model.variants newVariants)
                in
                    ( { model | variants = variants, showError = False }, toStorage variants )

            ShowCheckout ->
                if (List.any (\variant -> variant.count < variant.min) model.variants) then
                    ( { model | showError = True }, Effects.none )
                else
                    ( { model | viewType = CheckoutView }, Effects.none )

            ShowCart ->
                ( { model | viewType = CartView }, Effects.none )

            DeleteFromCart variantId ->
                let
                    variants = deleteFromCart variantId model.variants
                in
                    ( { model | variants = variants }, toStorage variants )

            ChangeCount variantId count ->
                let
                    variants = (List.map (changeCount variantId count) model.variants)
                in
                    ( { model | variants = variants, showError = False }, toStorage variants )

            Toggle ->
                ( { model | isShowed = (not model.isShowed) }, Effects.none )

            Email email ->
                ( { model | email = email }, Effects.none )

            Name name ->
                ( { model | name = name }, Effects.none )

            Checkout ->
                ( { model | error = "" }, toStripe card )

            ResponseFromStripe response ->
                case response of
                    Ok cardToken ->
                        ( model, savePayment cardToken model )

                    Err error ->
                        ( { model | error = (Maybe.withDefault "" (Dict.get error errorMsg)) }, Effects.none )

            RecievePaymentResponse response ->
                case response of
                    Ok str ->
                        ( initModel, toOrderCreated True )

                    _ ->
                        ( { model | error = "Неверный email или неуказано имя" }, Effects.none )


savePayment : String -> Model -> Effects Action
savePayment cardToken model =
    safePost (paymentToJson cardToken model)
        |> Task.map RecievePaymentResponse
        |> Effects.task


safePost : String -> Task a (Result Http.Error String)
safePost body =
    Task.toResult (paymentPost body)


paymentPost : String -> Task Http.Error String
paymentPost body =
    let
        request =
            { verb = "POST"
            , headers = [ ( "Content-Type", "application/json" ) ]
            , url = "http://localhost:3000/api/v1/orders/create"
            , body = Http.string body
            }
    in
        Http.fromJson (Decode.string) (Http.send Http.defaultSettings request)


paymentToJson : String -> Model -> String
paymentToJson cardToken model =
    let
        encoder =
            Encode.object
                [ ( "name", Encode.string model.name )
                , ( "email", Encode.string model.email )
                , ( "card_token", Encode.string cardToken )
                , ( "order_items_attributes", Encode.list (variantsToJson model.variants) )
                ]
    in
        Encode.encode 2 encoder


variantsToJson : List Variant -> List Encode.Value
variantsToJson variants =
    let
        encodeVariant variant =
            Encode.object
                [ ( "variant_id", Encode.int variant.id )
                , ( "count", Encode.int variant.count )
                ]
    in
        List.map encodeVariant variants


changeCount : Int -> Int -> Variant -> Variant
changeCount variantId count variant =
    if variant.id == variantId then
        { variant | count = count }
    else
        variant


inCart : List Variant -> Variant -> Bool
inCart cartItems variant =
    List.member variant.id (variantsIds cartItems)


variantsIds : List Variant -> List Int
variantsIds variants =
    (List.map .id variants)


addVariants : List Variant -> List Variant -> List Variant
addVariants oldVariants newVariants =
    case newVariants of
        [] ->
            oldVariants

        head :: tail ->
            if inCart oldVariants head then
                addVariants (increaseItemsCount head oldVariants) tail
            else
                addVariants (head :: oldVariants) tail


increaseItemCount : Variant -> Variant -> Variant
increaseItemCount item1 item2 =
    if item1.id == item2.id then
        { item2 | count = item1.count + item2.count }
    else
        item2


increaseItemsCount : Variant -> List Variant -> List Variant
increaseItemsCount variant variants =
    List.map (increaseItemCount variant) variants


deleteFromCart : Int -> List Variant -> List Variant
deleteFromCart variantId variants =
    (List.filter (\item -> item.id /= variantId) variants)



-- VIEW


cartHead : Html
cartHead =
    div
        [ classList [ ( "cart-header", True ) ] ]
        [ div
            [ classList [ ( "six-column", True ) ] ]
            [ text "Товар" ]
        , div
            [ classList [ ( "three-column", True ) ] ]
            [ text "Количество" ]
        , div
            [ classList [ ( "two-column", True ) ] ]
            [ text "Цена" ]
        , div
            [ classList [ ( "one-column", True ) ] ]
            []
        ]


errorView : Int -> List Html
errorView min =
    [ div
        [ classList
            [ ( "error", True )
            ]
        ]
        [ text <| "Для совершения заказа этого товара должно быть не менее " ++ (toString min) ++ "шт." ]
    ]


itemView : Signal.Address Action -> Bool -> Variant -> Html
itemView address showError variant =
    (div
        [ classList [ ( "cart-product", True ) ] ]
    )
        <| (if showError && variant.count < variant.min then
                errorView variant.min
            else
                []
           )
        ++ [ div
                [ classList [ ( "six-column", True ) ] ]
                [ div
                    [ classList [ ( "four-column", True ) ]
                    , style
                        [ ( "background-image", "url('" ++ variant.imageUrl ++ "')" )
                        , ( "width", "50px" )
                        , ( "height", "50px" )
                        , ( "background-repeat", "no-repeat" )
                        , ( "background-size", "cover" )
                        , ( "background-position", "center" )
                        ]
                    ]
                    []
                , div
                    [ classList [ ( "eight-column", True ) ] ]
                    [ text (variant.name ++ ". " ++ variant.description) ]
                ]
           , div
                [ classList [ ( "three-column", True ) ] ]
                [ input
                    [ type' "number"
                    , value (toString variant.count)
                    , name ("product[" ++ (toString variant.id) ++ "]")
                    , Html.Attributes.min (toString variant.min)
                    , on
                        "input"
                        targetValue
                        (\str ->
                            case (String.toInt str) of
                                Ok val ->
                                    Signal.message address (ChangeCount variant.id val)

                                _ ->
                                    Signal.message address NoOp
                        )
                    ]
                    []
                ]
           , div
                [ classList [ ( "two-column", True ) ]
                , style [ ( "margin-top", "5px" ) ]
                ]
                [ text ((toString variant.price) ++ "руб.") ]
           , div
                [ classList [ ( "one-column", True ) ] ]
                [ button
                    [ Html.Events.onClick address (DeleteFromCart variant.id) ]
                    [ text "×" ]
                ]
           ]


overlayDiv : Signal.Address Action -> Model -> Html
overlayDiv address model =
    div
        [ style
            [ ( "position", "fixed" )
            , ( "display"
              , (if model.isShowed then
                    "block"
                 else
                    "none"
                )
              )
            , ( "left", "0" )
            , ( "background", "transparent" )
            , ( "bottom", "0" )
            , ( "width", "100%" )
            , ( "height", "100%" )
            ]
        , onClick address (Toggle)
        , classList [ ( "product-overlay", True ) ]
        ]
        []


view : Signal.Address Action -> Model -> Html
view address model =
    div
        []
        [ overlayDiv address model
        , div
            [ classList [ ( "cart-container", True ) ]
            , style
                [ (if (List.isEmpty model.variants) then
                    ( "display", "none" )
                   else
                    ( "display", "block" )
                  )
                ]
            ]
            ([ div
                [ classList [ ( "cart-button", True ) ]
                , onClick address (Toggle)
                ]
                []
             ]
                ++ [ (getView address model) ]
            )
        ]


total : Model -> Float
total model =
    let
        subTotal item =
            (toFloat item.count) * item.price
    in
        List.sum
            <| List.map subTotal model.variants


showCart : Signal.Address Action -> Model -> Html
showCart address model =
    if model.isShowed then
        div
            [ classList [ ( "cart-items", True ) ] ]
            ([ cartHead ]
                ++ (List.map (itemView address model.showError) model.variants)
                ++ [ div
                        [ style [ ( "margin-top", "20px" ) ] ]
                        [ button
                            [ Html.Events.onClick address (ShowCheckout) ]
                            [ text "Оплатить" ]
                        , div
                            [ style
                                [ ( "float", "right" )
                                , ( "margin-top", "10px" )
                                ]
                            ]
                            [ text
                                <| "Итого: "
                                ++ (toString <| total model)
                                ++ "руб."
                            ]
                        ]
                   ]
            )
    else
        div [] []


getView : Signal.Address Action -> Model -> Html
getView address model =
    case model.viewType of
        CartView ->
            showCart address model

        CheckoutView ->
            showCheckOut address model


setExpValue : String -> String -> String
setExpValue month year =
    if (String.length month) >= 2 then
        month ++ "/" ++ year
    else
        month


showCheckOut : Signal.Address Action -> Model -> Html
showCheckOut address model =
    if model.isShowed then
        let
            card = model.card
        in
            div
                [ classList [ ( "cart-checkout", True ) ] ]
                [ div
                    [ classList
                        [ ( "checkout-form", True ) ]
                    ]
                    [ div
                        [ classList [ ( "error", True ) ] ]
                        [ text
                            (if (String.length model.error) > 0 then
                                model.error
                             else
                                ""
                            )
                        ]
                    , Html.form
                        [ method "POST" ]
                        [ fieldset
                            []
                            [ input
                                [ name "name"
                                , on "input" targetValue (\name -> Signal.message address (Name name))
                                , value model.name
                                , type' "text"
                                , placeholder "Ваше имя"
                                , required True
                                ]
                                []
                            , input
                                [ name "email"
                                , on "input" targetValue (\email -> Signal.message address (Email email))
                                , value model.email
                                , type' "email"
                                , placeholder "Ваш еmail"
                                , required True
                                ]
                                []
                            , input
                                [ name "cardNumber"
                                , on
                                    "input"
                                    targetValue
                                    (\num -> Signal.message address (CardNumber num))
                                , value card.cardNumber
                                , placeholder "Номер карты"
                                , type' "tel"
                                , required True
                                ]
                                []
                            , input
                                [ name "cvc"
                                , style [ ( "width", "50%" ), ( "float", "left" ) ]
                                , on
                                    "input"
                                    targetValue
                                    (\cvc -> Signal.message address (CardVerification cvc))
                                , value card.cvc
                                , placeholder "CVC"
                                , maxlength 4
                                , type' "tel"
                                , required True
                                ]
                                []
                            , input
                                [ name "exp"
                                , style [ ( "width", "50%" ) ]
                                , on "input" targetValue (\exp -> Signal.message address (CardExpire exp))
                                , maxlength 7
                                , placeholder "ММ/ГГГГ"
                                , type' "text"
                                , value (setExpValue card.expMonth card.expYear)
                                , required True
                                ]
                                []
                            ]
                        , a
                            [ onClick address ShowCart
                            ]
                            [ text "Товары" ]
                        , button
                            [ type' "button"
                            , onClick address Checkout
                            ]
                            [ text <| "Оплатить " ++ (toString <| total model) ++ "руб." ]
                        ]
                    ]
                ]
    else
        div [] []
