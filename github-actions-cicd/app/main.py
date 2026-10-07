import os

from flask import Flask, jsonify, request

from app.calculator import OPERATIONS

app = Flask(__name__)
VERSION = os.environ.get("APP_VERSION", "dev")


@app.get("/")
def index():
    return jsonify(app="calculator-api", author="Anushka Jain", version=VERSION)


@app.get("/health")
def health():
    return jsonify(status="ok")


@app.get("/api/<operation>")
def calculate(operation):
    if operation not in OPERATIONS:
        return jsonify(error=f"unknown operation '{operation}'"), 404
    try:
        a = float(request.args["a"])
        b = float(request.args["b"])
        return jsonify(operation=operation, a=a, b=b, result=OPERATIONS[operation](a, b))
    except KeyError:
        return jsonify(error="query parameters 'a' and 'b' are required"), 400
    except ValueError as e:
        return jsonify(error=str(e)), 400


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", "5000")))
