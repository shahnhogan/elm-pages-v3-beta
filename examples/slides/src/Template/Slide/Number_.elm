module Template.Slide.Number_ exposing (Model, Msg, StaticData, template)

import Browser.Events
import Browser.Navigation
import DataSource
import DataSource.File as StaticFile
import Document exposing (Document)
import Head
import Head.Seo as Seo
import Html.Styled as Html
import Html.Styled.Attributes exposing (css)
import Json.Decode as Decode
import Markdown.Block
import Markdown.Parser
import Markdown.Renderer
import MarkdownRenderer
import OptimizedDecoder
import Pages.ImagePath as ImagePath
import Shared
import Tailwind.Utilities as Tw
import Template exposing (StaticPayload, Template)


type alias Model =
    ()


type Msg
    = OnKeyPress (Maybe Direction)


type alias RouteParams =
    { number : String }


template : Template.TemplateWithState RouteParams StaticData Model Msg
template =
    Template.withStaticData
        { head = head
        , staticRoutes =
            slideCount
                |> DataSource.map
                    (\count ->
                        List.range 1 (count - 1)
                            |> List.map String.fromInt
                            |> List.map RouteParams
                    )
        , staticData = staticData
        }
        |> Template.buildWithLocalState
            { view = view
            , init = \routeParams -> ( (), Cmd.none )
            , update =
                \sharedModel pageStaticData routeParams msg model ->
                    case msg of
                        OnKeyPress (Just direction) ->
                            let
                                currentSlide =
                                    String.toInt routeParams.number |> Maybe.withDefault 0

                                nextSlide =
                                    clamp
                                        1
                                        (pageStaticData.totalCount - 1)
                                        (case direction of
                                            Right ->
                                                currentSlide + 1

                                            Left ->
                                                currentSlide - 1
                                        )
                            in
                            ( model
                            , sharedModel.navigationKey
                                |> Maybe.map
                                    (\navKey ->
                                        Browser.Navigation.pushUrl navKey
                                            ("/slide/"
                                                ++ String.fromInt
                                                    nextSlide
                                            )
                                    )
                                |> Maybe.withDefault Cmd.none
                            )

                        _ ->
                            ( model, Cmd.none )
            , subscriptions =
                \routeParams path model ->
                    Browser.Events.onKeyDown keyDecoder |> Sub.map OnKeyPress
            }


type Direction
    = Left
    | Right


keyDecoder : Decode.Decoder (Maybe Direction)
keyDecoder =
    Decode.map toDirection (Decode.field "key" Decode.string)


toDirection : String -> Maybe Direction
toDirection string =
    case string of
        "ArrowLeft" ->
            Just Left

        "ArrowRight" ->
            Just Right

        _ ->
            Nothing


staticData : RouteParams -> DataSource.DataSource StaticData
staticData routeParams =
    DataSource.map2 StaticData
        (slideBody routeParams)
        slideCount


slideBody : RouteParams -> DataSource.DataSource (List (Html.Html Msg))
slideBody route =
    StaticFile.request
        "slides.md"
        (StaticFile.body
            |> OptimizedDecoder.andThen
                (\rawBody ->
                    case rawBody |> Markdown.Parser.parse of
                        Ok okBlocks ->
                            case
                                okBlocks
                                    |> markdownIndexedByHeading (route.number |> String.toInt |> Maybe.withDefault 1)
                                    |> Markdown.Renderer.render MarkdownRenderer.renderer
                            of
                                Ok renderedBody ->
                                    OptimizedDecoder.succeed renderedBody

                                Err error ->
                                    OptimizedDecoder.fail error

                        Err _ ->
                            OptimizedDecoder.fail ""
                )
        )


slideCount : DataSource.DataSource Int
slideCount =
    StaticFile.request "slides.md"
        (StaticFile.body
            |> OptimizedDecoder.andThen
                (\rawBody ->
                    case rawBody |> Markdown.Parser.parse of
                        Ok okBlocks ->
                            okBlocks
                                |> Markdown.Block.foldl
                                    (\block h2CountSoFar ->
                                        case block of
                                            Markdown.Block.Heading Markdown.Block.H2 _ ->
                                                h2CountSoFar + 1

                                            _ ->
                                                h2CountSoFar
                                    )
                                    0
                                |> OptimizedDecoder.succeed

                        Err _ ->
                            OptimizedDecoder.fail ""
                )
        )


markdownIndexedByHeading :
    Int
    -> List Markdown.Block.Block
    -> List Markdown.Block.Block
markdownIndexedByHeading index markdownBlocks =
    Markdown.Block.foldl
        (\block ( currentIndex, markdownToKeep ) ->
            case block of
                Markdown.Block.Heading Markdown.Block.H2 _ ->
                    let
                        newIndex =
                            currentIndex + 1
                    in
                    --_ ->
                    if newIndex == index then
                        ( newIndex, block :: markdownToKeep )

                    else
                        ( newIndex, markdownToKeep )

                _ ->
                    if currentIndex == index then
                        ( currentIndex, block :: markdownToKeep )

                    else
                        ( currentIndex, markdownToKeep )
        )
        ( 0, [] )
        markdownBlocks
        |> Tuple.second
        |> List.reverse


head :
    StaticPayload StaticData RouteParams
    -> List Head.Tag
head static =
    Seo.summary
        { canonicalUrlOverride = Nothing
        , siteName = "elm-pages"
        , image =
            { url = ImagePath.build [ "TODO" ]
            , alt = "elm-pages logo"
            , dimensions = Nothing
            , mimeType = Nothing
            }
        , description = "TODO"
        , locale = Nothing
        , title = "TODO title" -- metadata.title -- TODO
        }
        |> Seo.website


type alias StaticData =
    { body : List (Html.Html Msg)
    , totalCount : Int
    }


view :
    Model
    -> Shared.Model
    -> StaticPayload StaticData RouteParams
    -> Document Msg
view model sharedModel static =
    { title = "TODO title"
    , body =
        [ Html.div
            [ css
                [ Tw.prose
                , Tw.max_w_lg
                , Tw.px_8
                , Tw.py_6
                ]
            ]
            (static.static.body
                ++ [ Html.text static.routeParams.number ]
            )
        ]
    }
