import importlib.util
import io
import json
import os
from pathlib import Path
import unittest
from unittest.mock import patch
import urllib.error


script_path = os.environ.get("ANONYMIZE_SCRIPT", str(Path(__file__).with_name("anonymize.py")))
specification = importlib.util.spec_from_file_location("anonymize", script_path)
anonymize = importlib.util.module_from_spec(specification)
specification.loader.exec_module(anonymize)


class AnonymizeTests(unittest.TestCase):
    def request(self, input_text, output_text, output_format="text", finish_reason="stop"):
        response = io.BytesIO(json.dumps({
            "choices": [{"finish_reason": finish_reason, "message": {"content": output_text}}]
        }).encode())
        with patch.object(anonymize.urllib.request, "build_opener") as build_opener:
            build_opener.return_value.open.return_value = response
            result = anonymize.anonymize(input_text, output_format, "http://127.0.0.1:8080/v1", "qwen", 120)
            request = build_opener.return_value.open.call_args.args[0]
            return result, json.loads(request.data)

    def test_text(self):
        result, request = self.request("Contact Alice at alice@example.com", "Contact [PERSON_1] at [EMAIL_1]")
        self.assertEqual(result, "Contact [PERSON_1] at [EMAIL_1]\n")
        self.assertNotIn("response_format", request)
        self.assertEqual(request["reasoning_effort"], "none")
        self.assertEqual(request["messages"][1]["content"], "Contact Alice at alice@example.com")
        self.assertIn("untrusted", request["messages"][0]["content"])

    def test_json_object(self):
        result, request = self.request('{"name":"Alice","count":3}',
                                       '{"result":{"name":"[PERSON_1]","count":3}}', "json")
        self.assertEqual(json.loads(result), {"name": "[PERSON_1]", "count": 3})
        self.assertEqual(request["response_format"], {"type": "json_object"})
        self.assertEqual(json.loads(request["messages"][1]["content"]),
                         {"result": {"name": "Alice", "count": 3}})

    def test_json_arrays_and_scalars(self):
        for value in [["Alice"], "Alice", 42, True, None]:
            with self.subTest(value=value):
                result, request = self.request(json.dumps(value), json.dumps({"result": value}), "json")
                self.assertEqual(json.loads(result), value)

    def test_invalid_input_never_calls_api(self):
        for input_text in ["not json", '{"name":}', "NaN", '{"name":"Alice","name":"Bob"}']:
            with self.subTest(input_text=input_text):
                with patch.object(anonymize.urllib.request, "build_opener") as build_opener:
                    with self.assertRaisesRegex(anonymize.AnonymizeError, "Input is not valid JSON"):
                        anonymize.anonymize(input_text, "json", "http://localhost/v1", "qwen", 120)
                    build_opener.assert_not_called()

    def test_invalid_model_json_is_rejected(self):
        for output_text in ["not json", '```json\n{"result":{}}\n```', '{"result":NaN}',
                            '{}', '{"result":{},"comment":"done"}', '{"result":{},"result":[]}']:
            with self.subTest(output_text=output_text):
                with self.assertRaisesRegex(anonymize.AnonymizeError, "Qwen output is not valid JSON"):
                    self.request("{}", output_text, "json")

    def test_truncated_response_is_rejected(self):
        with self.assertRaisesRegex(anonymize.AnonymizeError, "did not finish"):
            self.request("Alice", "[PERSON", finish_reason="length")

    def test_empty_response_is_rejected(self):
        with self.assertRaisesRegex(anonymize.AnonymizeError, "no anonymized content"):
            self.request("Alice", "")

    def test_http_error_does_not_expose_input(self):
        with patch.object(anonymize.urllib.request, "build_opener") as build_opener:
            build_opener.return_value.open.side_effect = urllib.error.HTTPError(
                "http://localhost", 503, "sensitive input", {}, None)
            with self.assertRaisesRegex(anonymize.AnonymizeError, "^Qwen API returned HTTP 503.$"):
                anonymize.anonymize("Alice", "text", "http://localhost/v1", "qwen", 120)

    def test_cli_errors_write_no_stdout(self):
        for input_text, arguments in [("", []), ("secret invalid json", ["--format", "json"])]:
            with self.subTest(arguments=arguments):
                with patch.object(anonymize.sys, "argv", ["anonymize", *arguments]), \
                     patch.object(anonymize.sys, "stdin", io.StringIO(input_text)), \
                     patch.object(anonymize.sys, "stdout", io.StringIO()) as stdout, \
                     patch.object(anonymize.sys, "stderr", io.StringIO()) as stderr:
                    self.assertEqual(anonymize.main(), 1)
                    self.assertEqual(stdout.getvalue(), "")
                    self.assertNotIn("secret", stderr.getvalue())


if __name__ == "__main__":
    unittest.main()
