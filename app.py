from flask import Flask

app = Flask(__name__)

@app.route('/')
def hello():
    return "Hello from Anthony!"

if __name__ == '__main__':
    # Bind to 0.0.0.0 so the app is accessible externally
    app.run(host='0.0.0.0', port=5000)