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
import Debug
import String


app =
    StartApp.start
        { init = init
        , update = update
        , view = view
        , inputs = [ toCartInput ]
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


saveToStorageMailbox : Signal.Mailbox (List Variant)
saveToStorageMailbox =
    Signal.mailbox []


toStorage : List Variant -> Effects Action
toStorage variants =
    Signal.send saveToStorageMailbox.address variants
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


type alias Model =
    { clientEmail : String
    , clientName : String
    , variants : List Variant
    , isShowed : Bool
    , viewType : ViewType
    }


initModel : Model
initModel =
    Model "" "" [] False CartView


init : ( Model, Effects.Effects Action )
init =
    ( initModel, Effects.none )



-- ACTION


type Action
    = NoOp
    | AddToCart (List Variant)
    | Toggle
    | Checkout
    | DeleteFromCart Int
    | ChangeCount Int Int


type ViewType
    = CartView
    | CheckoutView


update : Action -> Model -> ( Model, Effects.Effects Action )
update action model =
    case action of
        NoOp ->
            ( model, Effects.none )

        AddToCart newVariants ->
            let
                variants = (addVariants model.variants newVariants)
            in
                ( { model | variants = variants }, toStorage variants )

        Checkout ->
            ( { model | viewType = CheckoutView }, Effects.none )

        DeleteFromCart variantId ->
            let
                variants = deleteFromCart variantId model.variants
            in
                ( { model | variants = variants }, toStorage variants )

        ChangeCount variantId count ->
            let
                variants = (List.map (changeCount variantId count) model.variants)
            in
                ( { model | variants = variants }, toStorage variants )

        Toggle ->
            ( { model | isShowed = (not model.isShowed) }, Effects.none )


changeCount : Int -> Int -> Variant -> Variant
changeCount variantId count variant =
    if variant.id == variantId then
        { variant | count = count }
    else
        variant


inNew : List Variant -> Variant -> Bool
inNew newVariants variant =
    List.member variant.id (variantsIds newVariants)


variantsIds : List Variant -> List Int
variantsIds variants =
    (List.map .id variants)


addVariants : List Variant -> List Variant -> List Variant
addVariants variants newVariants =
    newVariants
        ++ (notInNew (List.partition (inNew newVariants) variants))


notInNew : ( List Variant, List Variant ) -> List Variant
notInNew ( variants, needVariants ) =
    needVariants


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


itemView : Signal.Address Action -> Variant -> Html
itemView address variant =
    div
        [ classList [ ( "cart-product", True ) ] ]
        [ div
            [ classList [ ( "six-column", True ) ] ]
            [ img
                [ classList [ ( "four-column", True ) ]
                , src variant.imageUrl
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


view : Signal.Address Action -> Model -> Html
view address model =
    div
        []
        [ div
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


showCart : Signal.Address Action -> Model -> Html
showCart address model =
    if model.isShowed then
        div
            [ classList [ ( "cart-items", True ) ] ]
            ([ cartHead ]
                ++ (List.map (itemView address) model.variants)
                ++ [ div
                        [ style [ ( "margin-top", "20px" ) ] ]
                        [ button
                            [ Html.Events.onClick address (Checkout) ]
                            [ text "Оплатить" ]
                        , div
                            [ style [ ( "float", "right" ) ] ]
                            [ text
                                <| "Итого: "
                                ++ (toString
                                        <| List.sum
                                        <| List.map
                                            (\item -> (toFloat item.count) * item.price)
                                            model.variants
                                   )
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


showCheckOut address model =
    div [] []
