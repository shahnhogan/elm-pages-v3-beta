module Form exposing (..)

import DataSource exposing (DataSource)
import Dict exposing (Dict)
import Html exposing (Html)
import Html.Attributes as Attr
import Server.Request as Request exposing (Request)


type Form value view
    = Form
        (List (FieldInfo view))
        (Request value)
        (Request
            (DataSource
                (List
                    ( String
                    , { errors : List String
                      , raw : String
                      }
                    )
                )
            )
        )


type Field view
    = Field (FieldInfo view)


type alias FieldInfo view =
    { name : String
    , initialValue : Maybe String
    , type_ : String
    , min : Maybe String
    , max : Maybe String
    , serverValidation : String -> DataSource (List String)
    , toHtml :
        FinalFieldInfo
        -> Maybe { raw : String, errors : List String }
        -> view
    }


type alias FinalFieldInfo =
    { name : String
    , initialValue : Maybe String
    , type_ : String
    , min : Maybe String
    , max : Maybe String
    , serverValidation : String -> DataSource (List String)
    }


succeed : constructor -> Form constructor view
succeed constructor =
    Form []
        (Request.succeed constructor)
        (Request.succeed (DataSource.succeed []))


toInputRecord :
    String
    -> Maybe { raw : String, errors : List String }
    -> FinalFieldInfo
    ->
        { toInput : List (Html.Attribute Never)
        , toLabel : List (Html.Attribute Never)
        , errors : List String
        }
toInputRecord name info field =
    { toInput =
        [ Attr.name name |> Just
        , case info of
            Just { raw } ->
                Just (Attr.value raw)

            _ ->
                field.initialValue |> Maybe.map Attr.value
        , field.type_ |> Attr.type_ |> Just
        , field.min |> Maybe.map Attr.min
        , field.max |> Maybe.map Attr.max
        , Attr.required True |> Just
        ]
            |> List.filterMap identity
    , toLabel =
        [ Attr.for name ]
    , errors = info |> Maybe.map .errors |> Maybe.withDefault []
    }


input :
    String
    ->
        ({ toInput : List (Html.Attribute Never)
         , toLabel : List (Html.Attribute Never)
         , errors : List String
         }
         -> view
        )
    -> Field view
input name toHtmlFn =
    Field
        { name = name
        , initialValue = Nothing
        , type_ = "text"
        , min = Nothing
        , max = Nothing
        , serverValidation = \_ -> DataSource.succeed []
        , toHtml =
            \fieldInfo info ->
                toHtmlFn (toInputRecord name info fieldInfo)
        }


submit :
    ({ attrs : List (Html.Attribute Never)
     }
     -> view
    )
    -> Field view
submit toHtmlFn =
    Field
        { name = ""
        , initialValue = Nothing
        , type_ = "submit"
        , min = Nothing
        , max = Nothing
        , serverValidation = \_ -> DataSource.succeed []
        , toHtml =
            \fieldInfo info ->
                toHtmlFn
                    { attrs =
                        [ Attr.type_ "submit" ]
                    }
        }



--number : { name : String, label : String } -> Field
--number { name, label } =
--    Field
--        { name = name
--        , label = label
--        , initialValue = Nothing
--        , type_ = "number"
--        , min = Nothing
--        , max = Nothing
--        , serverValidation = \_ -> DataSource.succeed []
--        }


date :
    String
    ->
        ({ toInput : List (Html.Attribute Never)
         , toLabel : List (Html.Attribute Never)
         , errors : List String
         }
         -> view
        )
    -> Field view
date name toHtmlFn =
    Field
        { name = name
        , initialValue = Nothing
        , type_ = "date"
        , min = Nothing
        , max = Nothing
        , serverValidation = \_ -> DataSource.succeed []
        , toHtml =
            \fieldInfo info ->
                toHtmlFn (toInputRecord name info fieldInfo)
        }


withMin : Int -> Field view -> Field view
withMin min (Field field) =
    Field { field | min = min |> String.fromInt |> Just }


withMax : Int -> Field view -> Field view
withMax max (Field field) =
    Field { field | max = max |> String.fromInt |> Just }


withMinDate : String -> Field view -> Field view
withMinDate min (Field field) =
    Field { field | min = min |> Just }


withMaxDate : String -> Field view -> Field view
withMaxDate max (Field field) =
    Field { field | max = max |> Just }


type_ : String -> Field view -> Field view
type_ typeName (Field field) =
    Field
        { field | type_ = typeName }


withInitialValue : String -> Field view -> Field view
withInitialValue initialValue (Field field) =
    Field { field | initialValue = Just initialValue }


withServerValidation : (String -> DataSource (List String)) -> Field view -> Field view
withServerValidation serverValidation (Field field) =
    Field
        { field
            | serverValidation = serverValidation
        }


required : Field view -> Form (String -> form) view -> Form form view
required (Field field) (Form fields decoder serverValidations) =
    let
        thing : Request (DataSource (List ( String, { raw : String, errors : List String } )))
        thing =
            Request.map2
                (\arg1 arg2 ->
                    arg1
                        |> DataSource.map2 (::)
                            (field.serverValidation arg2
                                |> DataSource.map
                                    (\validationErrors ->
                                        ( field.name
                                        , { errors = validationErrors
                                          , raw = arg2
                                          }
                                        )
                                    )
                            )
                )
                serverValidations
                (Request.formField_ field.name)
    in
    Form (field :: fields)
        (decoder
            |> Request.andMap (Request.formField_ field.name)
        )
        thing


append : Field view -> Form form view -> Form form view
append (Field field) (Form fields decoder serverValidations) =
    Form (field :: fields)
        decoder
        serverValidations


simplify : FieldInfo view -> FinalFieldInfo
simplify field =
    { name = field.name
    , initialValue = field.initialValue
    , type_ = field.type_
    , min = field.min
    , max = field.max
    , serverValidation = field.serverValidation
    }



{-
   - If there is at least one file field, then use enctype multi-part. Otherwise use form encoding (or maybe GET with query params?).
   - Should it ever use GET forms?
   - Ability to do server-only validations (like uniqueness check with DataSource)
   - Return error messages that can be presented inline from server response (both on full page load and on client-side request)
   - Add functions for built-in form validations
-}


toHtml : (List (Html.Attribute msg) -> List view -> view) -> Maybe (Dict String { raw : String, errors : List String }) -> Form value view -> view
toHtml toForm serverValidationErrors (Form fields decoder serverValidations) =
    --Html.form
    toForm
        [ Attr.method "POST"
        ]
        (fields
            |> List.reverse
            |> List.map
                (\field ->
                    field.toHtml (simplify field)
                        (serverValidationErrors
                            |> Maybe.andThen (Dict.get field.name)
                        )
                 --|> Html.map never
                )
         --++ [ Html.input [ Attr.type_ "submit" ] []
         --   ]
        )



--((fields
--    |> List.reverse
--    |> List.map
--        (\field ->
--            Html.div []
--                [ case serverValidationErrors |> Dict.get field.name of
--                    Just entry ->
--                        let
--                            { raw, errors } =
--                                entry
--                        in
--                        case entry.errors of
--                            first :: rest ->
--                                Html.div []
--                                    [ Html.ul
--                                        [ Attr.style "border" "solid red"
--                                        ]
--                                        (List.map
--                                            (\error ->
--                                                Html.li []
--                                                    [ Html.text error
--                                                    ]
--                                            )
--                                            (first :: rest)
--                                        )
--                                    , Html.label
--                                        []
--                                        [ Html.text field.label
--                                        , Html.input
--                                            ([ Attr.name field.name |> Just
--
--                                             --, field.initialValue |> Maybe.map Attr.value
--                                             , raw |> Attr.value |> Just
--                                             , field.type_ |> Attr.type_ |> Just
--                                             , field.min |> Maybe.map Attr.min
--                                             , field.max |> Maybe.map Attr.max
--                                             , Attr.required True |> Just
--                                             ]
--                                                |> List.filterMap identity
--                                            )
--                                            []
--                                        ]
--                                    ]
--
--                            _ ->
--                                Html.div []
--                                    [ Html.label
--                                        []
--                                        [ Html.text field.label
--                                        , Html.input
--                                            ([ Attr.name field.name |> Just
--
--                                             --, field.initialValue |> Maybe.map Attr.value
--                                             , raw |> Attr.value |> Just
--                                             , field.type_ |> Attr.type_ |> Just
--                                             , field.min |> Maybe.map Attr.min
--                                             , field.max |> Maybe.map Attr.max
--                                             , Attr.required True |> Just
--                                             ]
--                                                |> List.filterMap identity
--                                            )
--                                            []
--                                        ]
--                                    ]
--
--                    Nothing ->
--                        Html.div []
--                            [ Html.label
--                                []
--                                [ Html.text field.label
--                                , Html.input
--                                    ([ Attr.name field.name |> Just
--                                     , field.initialValue |> Maybe.map Attr.value
--                                     , field.type_ |> Attr.type_ |> Just
--                                     , field.min |> Maybe.map Attr.min
--                                     , field.max |> Maybe.map Attr.max
--                                     , Attr.required True |> Just
--                                     ]
--                                        |> List.filterMap identity
--                                    )
--                                    []
--                                ]
--                            ]
--                ]
--        )
-- )
--    ++ [ Html.input [ Attr.type_ "submit" ] []
--       ]
--)


toRequest : Form value view -> Request value
toRequest (Form fields decoder serverValidations) =
    Request.expectFormPost
        (\_ ->
            decoder
        )


toRequest2 :
    Form value view
    ->
        Request
            (DataSource
                (Result
                    (Dict
                        String
                        { errors : List String
                        , raw : String
                        }
                    )
                    ( value
                    , Dict
                        String
                        { errors : List String
                        , raw : String
                        }
                    )
                )
            )
toRequest2 (Form fields decoder serverValidations) =
    Request.map2
        (\decoded errors ->
            errors
                |> DataSource.map
                    (\validationErrors ->
                        if hasErrors validationErrors then
                            validationErrors
                                |> Dict.fromList
                                |> Err

                        else
                            Ok
                                ( decoded
                                , validationErrors
                                    |> Dict.fromList
                                )
                    )
        )
        (Request.expectFormPost
            (\_ ->
                decoder
            )
        )
        (Request.expectFormPost
            (\_ ->
                serverValidations
            )
        )


hasErrors : List ( String, { errors : List String, raw : String } ) -> Bool
hasErrors validationErrors =
    List.any
        (\( _, entry ) ->
            entry.errors |> List.isEmpty |> not
        )
        validationErrors
