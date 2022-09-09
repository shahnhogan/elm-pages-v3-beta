port module Cli exposing (main)

{-| -}

import Cli.Option as Option
import Cli.OptionsParser as OptionsParser
import Cli.Program as Program
import Cli.Validate
import Elm
import Elm.Annotation
import Elm.Case
import Gen.DataSource
import Gen.Effect
import Gen.Html
import Gen.Platform.Sub
import Gen.Server.Request
import Gen.Server.Response
import Gen.View
import Pages.Generate


type alias CliOptions =
    { moduleName : String
    }


program : Program.Config CliOptions
program =
    Program.config
        |> Program.add
            (OptionsParser.build CliOptions
                |> OptionsParser.with
                    (Option.requiredPositionalArg "module"
                        |> Option.validate (Cli.Validate.regex moduleNameRegex)
                    )
            )


moduleNameRegex : String
moduleNameRegex =
    "([A-Z][a-zA-Z_]*)(\\.([A-Z][a-zA-Z_]*))*"


main : Program.StatelessProgram Never {}
main =
    Program.stateless
        { printAndExitFailure = printAndExitFailure
        , printAndExitSuccess = printAndExitSuccess
        , init = init
        , config = program
        }


type alias Flags =
    Program.FlagsIncludingArgv {}


init : Flags -> CliOptions -> Cmd Never
init flags cliOptions =
    let
        file : Elm.File
        file =
            createFile (cliOptions.moduleName |> String.split ".")
    in
    writeFile
        { path = file.path
        , body = file.contents
        }


createFile : List String -> Elm.File
createFile moduleName =
    Pages.Generate.userFunction moduleName
        { action =
            \routeParams ->
                Gen.Server.Request.succeed
                    (Gen.DataSource.succeed
                        (Gen.Server.Response.render
                            (Elm.record [])
                        )
                    )
        , data =
            \routeParams ->
                Gen.Server.Request.succeed
                    (Gen.DataSource.succeed
                        (Gen.Server.Response.render
                            (Elm.record [])
                        )
                    )
        , head = \app -> Elm.list []
        , view =
            \maybeUrl sharedModel model app ->
                Gen.View.make_.view
                    { title = moduleName |> String.join "." |> Elm.string
                    , body = Elm.list [ Gen.Html.text "Here is your generated page!!!" ]
                    }
        , update =
            \pageUrl sharedModel app msg model ->
                Elm.Case.custom msg
                    (Elm.Annotation.named [] "Msg")
                    [ Elm.Case.branch0 "NoOp"
                        (Elm.tuple model Gen.Effect.none)
                    ]
        , init =
            \pageUrl sharedModel app ->
                Elm.tuple (Elm.record []) Gen.Effect.none
        , subscriptions =
            \maybePageUrl routeParams path sharedModel model ->
                Gen.Platform.Sub.none
        , types =
            { data =
                Elm.alias "Data" (Elm.Annotation.record [])
            , actionData =
                Elm.alias "ActionData" (Elm.Annotation.record [])
            , model =
                Elm.alias "Model" (Elm.Annotation.record [])
            , msg =
                Elm.customType "Msg" [ Elm.variant "NoOp" ]
            }
        }


port print : String -> Cmd msg


port printAndExitFailure : String -> Cmd msg


port printAndExitSuccess : String -> Cmd msg


port writeFile : { path : String, body : String } -> Cmd msg
