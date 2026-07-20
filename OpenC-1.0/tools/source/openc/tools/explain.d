module openc.tools.explain;

import openc.common : Result;
import std.file : readText;
import std.json : JSONType, JSONValue, parseJSON;
import std.string : join;

struct RuleExplanation {
    string id;
    string title;
    string summary;
    string phase;
    string category;
    string chapter;
    string[] examples;
    string[] related;

    string render() const {
        string result = id ~ " — " ~ title ~ "\n\n";
        result ~= summary ~ "\n\n";
        result ~= "phase: " ~ phase ~ "\ncategory: " ~ category ~ "\nchapter: " ~ chapter ~ "\n";
        if (examples.length) result ~= "\nexamples:\n  " ~ examples.join("\n  ") ~ "\n";
        if (related.length) result ~= "\nrelated:\n  " ~ related.join("\n  ") ~ "\n";
        return result;
    }
}

final class ExplanationDatabase {
private:
    RuleExplanation[string] rules;

public:
    static Result!ExplanationDatabase load(string ruleIndexPath) {
        JSONValue root;
        try root = parseJSON(readText(ruleIndexPath));
        catch (Exception error) return Result!ExplanationDatabase.failure(error.msg);
        auto database = new ExplanationDatabase();
        auto array = root.type == JSONType.array
            ? root.array
            : root.object.get("rules", JSONValue(JSONValue[].init)).array;
        foreach (entry; array) {
            auto object = entry.object;
            RuleExplanation explanation;
            explanation.id = object.get("id", JSONValue("")).str;
            explanation.title = object.get("title", JSONValue(explanation.id)).str;
            explanation.summary = object.get("summary", JSONValue("")).str;
            explanation.phase = object.get("phase", JSONValue("")).str;
            explanation.category = object.get("category", JSONValue("")).str;
            explanation.chapter = object.get("chapter", JSONValue("")).str;
            if (auto examples = "examples" in object) foreach (value; examples.array) explanation.examples ~= value.str;
            if (auto related = "related" in object) foreach (value; related.array) explanation.related ~= value.str;
            if (explanation.id.length) database.rules[explanation.id] = explanation;
        }
        return Result!ExplanationDatabase.success(database);
    }

    Result!RuleExplanation find(string id) {
        auto found = id in rules;
        return found is null ? Result!RuleExplanation.failure("unknown OpenC rule ID: " ~ id) : Result!RuleExplanation.success(*found);
    }
}
