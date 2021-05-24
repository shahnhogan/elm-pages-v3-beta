module QueryParamsTests exposing (all)

import Dict
import Expect
import QueryParams
import Test exposing (describe, test)


all =
    describe "QueryParams"
        [ test "run Url.Parser.Query" <|
            \() ->
                "q=mySearch"
                    |> QueryParams.fromString
                    |> QueryParams.parse (QueryParams.string "q")
                    |> Expect.equal (Ok "mySearch")
        , test "multiple params with same name" <|
            \() ->
                "q=mySearch1&q=mySearch2"
                    |> QueryParams.fromString
                    |> QueryParams.parse (QueryParams.strings "q")
                    |> Expect.equal (Ok [ "mySearch1", "mySearch2" ])
        , test "missing expected key" <|
            \() ->
                "otherKey=notQueryKey"
                    |> QueryParams.fromString
                    |> QueryParams.parse (QueryParams.string "q")
                    |> Expect.equal (Err "Missing key q")
        , test "optional key" <|
            \() ->
                "otherKey=notQueryKey"
                    |> QueryParams.fromString
                    |> QueryParams.parse (QueryParams.optionalString "q")
                    |> Expect.equal (Ok Nothing)
        , test "toDict" <|
            \() ->
                "q=mySearch1&q=mySearch2"
                    |> QueryParams.fromString
                    |> QueryParams.toDict
                    |> Expect.equal
                        (Dict.fromList
                            [ ( "q", [ "mySearch1", "mySearch2" ] )
                            ]
                        )
        ]
