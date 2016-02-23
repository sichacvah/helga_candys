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
    }
