# Anonymize

`anonymize` reads standard input and asks the local Qwen model to replace sensitive information with consistent placeholders. It writes only the result to standard output. Errors go to standard error and return exit status 1.

```sh
printf '%s\n' 'Contact Alice at alice@example.com' | anonymize
anonymize < notes.txt > notes-anonymized.txt
anonymize --format json < records.json > records-anonymized.json
```

Text is the default format. JSON mode accepts objects, arrays, and scalar values. It rejects malformed JSON, duplicate object keys, and non-standard constants such as `NaN` before calling Qwen. It requests JSON output and validates it before writing anything. It does not silently repair invalid model output or return truncated results.

The default API is Strata at `http://127.0.0.1:8080/v1`, with model `qwen3.8-flash-next`. Override it with `--url` and `--model`, or `ANONYMIZE_URL` and `ANONYMIZE_MODEL`. `--timeout` defaults to 120 seconds. Environment-configured HTTP proxies are ignored. Choosing a remote URL sends the input to that server.

The tool does not log input or output. The API server may log requests according to its own configuration. Model-based anonymization can miss sensitive data or change non-sensitive data. Review the output before sharing it; this is not a guarantee of de-identification.

Run the tests with:

```sh
python3 packages/anonymize/test_anonymize.py
```
