Code.require_file "../../acceptance_helper.exs", __FILE__

defmodule DatabaseModuleAcceptance do
  use ExUnit.Case, async: false

  @fixture_db "fixture"
  use CouchGears.Database.Fixtures

  @doc_x "x"
  @doc_x_body [{"_id","x"}, {"number", 1}]

  create_fixture @doc_x_body


  test "tries to find a undefined document" do
    assert DB.find_raw("missing_db", "missing_doc") == :no_db_file
    assert DB.find_raw(@fixture_db, "missing_doc") == :missing
  end

  test "returns a raw document" do
    doc_x = DB.find_raw(@fixture_db, @doc_x)
    assert  doc_x["_id"] == @doc_x
  end

  test "returns a document as a hash dict" do
    doc_x = DB.find(@fixture_db, @doc_x)
    assert doc_x["_id"] == @doc_x
  end

  test "updates a document as a hash dict" do
    doc = DB.find(@fixture_db, @doc_x)
    doc = HashDict.put(doc, "boolean", false)

    prev_rev = doc["_rev"]
    new_rev  = DB.update(@fixture_db, doc)

    doc = DB.find(@fixture_db, @doc_x)

    refute doc["boolean"]
    refute prev_rev == new_rev
  end

  test "returns a filtered document (except: ['number'])" do
    doc = DB.find(@fixture_db, @doc_x, [except: ["number"]])

    assert doc.size == 2
    assert doc["_id"] == @doc_x
  end

  test "returns a filtered document (only: ['_id'])" do
    doc = DB.find(@fixture_db, @doc_x, [only: ["_id"]])

    assert doc.size   == 1
    assert doc["_id"] == @doc_x
  end


  test "returns a document with rev" do
    doc = DB.find(@fixture_db, @doc_x)
    rev = doc["_rev"]

    new_rev = DB.update(@fixture_db, doc)

    refute new_rev == rev
    assert DB.find_with_rev(@fixture_db, @doc_x, rev)["_rev"] == rev
  end

  # test "tries to enum through undefined db" do
  #   callback = fn(_a,_b,acc) -> { :ok, acc } end
  #   assert DB.enum_docs("undefined", callback) == { :ok, 0, [] }
  # end

  test "enums through db" do
    callback = fn(_a,_b,acc) -> { :ok, acc ++ [:gotcha] } end
    assert DB.enum_docs(@fixture_db, callback) == { :ok, 1, [:gotcha] }
  end
end