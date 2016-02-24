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


toAction items =
    case items of
        Nothing ->
            NoOp

        Just cartItems ->
            AddToCart cartItems


toCart : Signal Action
toCart =
    Signal.map toAction addToCart


port addToCart : Signal (Maybe.Maybe InitParamsRecord)



-- MODEL


type alias Variant =
    { id : Int
    , name : String
    , description : String
    , price : Float
    , imageUrl : String
    , count : Int
    }


type alias Model =
    { clientEmail : String
    , clientName : String
    , cartItems : List Variant
    , isShowed : Bool
    }

initModel : Model
initModel =
    Model "" "" [] False

init : ( Model, Effects.Effects Action )
init =
    ( initModel, Effects.none )



-- ACTION

type Action
  = NoOp
  | AddToCart (List Variant)
  | Toggle



update : Action -> Model -> ( Model, Effects.Effects Action )
update action model =
  case action of
    NoOp -> 
      ( model, Effects.none)

    AddToCart newVariants ->
      ( { model | variants = (addVariants model.variants newVariants) }, Effects.none )

    Toggle ->
      ( { model | isShowed = (not model.isShowed) }, Effects.none )



inNew : List Variant -> Variant -> Bool
inNew newVariants variant =
    List.member variant.id (variantsIds newVariants)

variantsIds : List Variant -> List Int
variantsIds variants
  (List.map .id variants)

addVarinats : List Variant -> List Variant -> List Variant
addVariants variants newVariants =
  newVariants ++ (List.partition (inNew newVariants) variants)


-- VIEW

view : Signal.Address Action -> Model -> Html
view address model =
  div 
    [ classList [("cart-container", True)]
    , style 
        [ (if (List.empty model.variants) then
            ("display", "none")
          else
            ("display", "inline-block")
          ) 
        ] 
        
    ]
    [ div [ classList [("cart-button", True), onClick address (Toggle)]] []
    , div [ classList [("")]]
    ]




