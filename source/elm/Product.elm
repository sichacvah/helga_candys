module Product (..) where

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
        , inputs = [ showProductInput ]
        }


main =
    app.html


port tasks : Signal (Task.Task Never ())
port tasks =
    app.tasks


toAction paramsRecord =
    case paramsRecord of
        Nothing ->
            NoOp

        Just val ->
            RequestProduct val


showProductInput : Signal Action
showProductInput =
    Signal.map toAction initParams


port initParams : Signal (Maybe.Maybe InitParamsRecord)
type alias InitParamsRecord =
    { left : Float
    , top : Float
    , productId : Int
    }



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


type alias VariantWithoutCount =
    { id : Int
    , name : String
    , description : String
    , price : Float
    , imageUrl : String
    }


type alias Model =
    { left : Float
    , top : Float
    , productId : Int
    , name : String
    , min : Int
    , variants : List Variant
    , showed : Bool
    }


type alias Product =
    { name : String
    , id : Int
    , variants : List Variant
    }


type alias ProductFromServer =
    { name : String
    , id : Int
    , min : Int
    , variants : List VariantWithoutCount
    }


initModel : Model
initModel =
    Model 0 0 0 "" 0 [] False


init : ( Model, Effects Action )
init =
    ( initModel, Effects.none )


port addToCart : Signal (List Variant)
port addToCart =
    addToCartMailbox.signal


addToCartMailbox : Signal.Mailbox (List Variant)
addToCartMailbox =
    Signal.mailbox []


toCart : List Variant -> Effects Action
toCart variants =
    Signal.send addToCartMailbox.address variants
        |> Task.map (\_ -> Hide)
        |> Effects.task



-- ACTION


type Action
    = NoOp
    | Show (Result Http.Error ProductFromServer)
    | Hide
    | AddToCart
    | ChangeCount Int Int
    | RequestProduct InitParamsRecord


getProduct : Int -> Task Http.Error ProductFromServer
getProduct id =
    Http.get (productDecoder) ("http://0.0.0.0:3000/api/v1/products/" ++ (toString id))


safeGetProduct : Int -> Task x (Result Http.Error ProductFromServer)
safeGetProduct id =
    Task.toResult (getProduct id)


productRequest : Int -> Effects Action
productRequest id =
    safeGetProduct id
        |> Task.map Show
        |> Effects.task


productDecoder : Decode.Decoder ProductFromServer
productDecoder =
    Decode.object4
        ProductFromServer
        ("name" := Decode.string)
        ("id" := Decode.int)
        ("min" := Decode.int)
        ("variants"
            := (Decode.list
                    (Decode.object5
                        VariantWithoutCount
                        ("id" := Decode.int)
                        ("name" := Decode.string)
                        ("description" := Decode.string)
                        ("price" := Decode.float)
                        ("image_url" := Decode.string)
                    )
               )
        )


addCountToVariant : Int -> VariantWithoutCount -> Variant
addCountToVariant min variantWithoutCount =
    Variant
        variantWithoutCount.id
        variantWithoutCount.name
        variantWithoutCount.description
        variantWithoutCount.price
        variantWithoutCount.imageUrl
        0
        min


update : Action -> Model -> ( Model, Effects.Effects Action )
update action model =
    case action of
        NoOp ->
            ( model, Effects.none )

        Show productResult ->
            case productResult of
                Ok product ->
                    ( { model
                        | showed = True
                        , name = product.name
                        , min = product.min
                        , variants = (List.map (addCountToVariant product.min) product.variants)
                      }
                    , Effects.none
                    )

                _ ->
                    ( { model | showed = False }, Effects.none )

        AddToCart ->
            ( model, toCart (List.filter (\variant -> variant.count > 0) model.variants) )

        RequestProduct params ->
            ( { model
                | productId = params.productId
                , left = params.left
                , top = params.top
                , showed = False
              }
            , productRequest params.productId
            )

        ChangeCount variantId count ->
            ( { model | variants = List.map (changeCount variantId count) model.variants }, Effects.none )

        Hide ->
            ( { model | showed = False }, Effects.none )


changeCount : Int -> Int -> Variant -> Variant
changeCount id count variant =
    if variant.id == id then
        { variant | count = count }
    else
        variant



-- VIEW


(=>) =
    (,)


isShowed : Bool -> String
isShowed showed =
    if showed then
        "block"
    else
        "none"


productView : Signal.Address Action -> Int -> Variant -> Html
productView address min variant =
    div
        [ classList [ ( "product-info", True ) ] ]
        [ img
            [ src variant.imageUrl
            , classList [ ( "three-column", True ) ]
            ]
            []
        , div
            [ classList [ ( "product-name", True ), ( "six-column", True ) ] ]
            [ text (variant.name ++ ". " ++ variant.description)
            , div
                [ classList [ ( "product-count", True ) ] ]
                [ input
                    [ type' "number"
                    , value (toString variant.count)
                    , name "product_count"
                    , Html.Attributes.min "0"
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
            ]
        , div
            [ classList [ ( "product-price", True ), ( "three-column", True ) ] ]
            [ text ((toString variant.price) ++ " руб.") ]
        ]


showError : Int -> Html
showError min =
    div
        [ classList [ ( "product-error", True ) ] ]
        [ text ("Для оформления заказа нужно набрать минимальное количество товара - " ++ (toString min) ++ "шт.") ]


view : Signal.Address Action -> Model -> Html
view address model =
    div
        []
        [ div
            [ style
                [ ("position" => "fixed")
                , ("display" => (isShowed model.showed))
                , ("width" => "100%")
                , ("height" => "100%")
                ]
            , onClick address (Hide)
            , classList [ ( "product-overlay", True ) ]
            ]
            []
        , div
            [ classList [ ( "product-container", True ) ]
            , style
                [ ("display" => (isShowed model.showed))
                , ("top" => ((toString <| model.top + 30) ++ "px"))
                ]
            ]
            ([ h1
                [ style [ ("margin-top" => "1em") ] ]
                [ text ("Выберите вид :") ]
             ]
                ++ (List.map (productView address model.min) model.variants)
                ++ [ button
                        [ Html.Events.onClick address (AddToCart) ]
                        [ text "В корзину" ]
                   ]
            )
        ]
