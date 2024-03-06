import numpy as np
from mpyc.runtime import mpc
import sys


# Fixed random state for reproducibility
random_state = 3
tolerance = 1e-4

secnum = mpc.SecFxp(l=32, f=8)

def get_mpc_data(X, y):
    X_mpc = [[secnum(x, integral=False) for x in row] for row in X.tolist()]
    y_mpc = [secnum(y, integral=False) for y in y.tolist()]
    return X_mpc, y_mpc

def training(X_shared, y_shared, alpha,n_features,n_samples):
    # Initialize weights
    weights = secnum.array(np.zeros(n_features), integral=False)
    # Perform training step of logistic regression
    for _ in range(100):
        weights = logistic_regression_step(X_shared, y_shared, weights, alpha,n_features,n_samples)
    return weights

def logistic_regression_step(X_shared, y_shared, weights, alpha,n_features,n_samples):
    # Compute gradient
    gradient = compute_gradient(X_shared, y_shared, weights,n_features,n_samples)
    # Update weights
    weights = update_weights(weights, gradient, alpha,n_features,n_samples)
    return weights

def compute_gradient(X_shared, y_shared, weights,n_features,n_samples):
    # Compute gradient
    gradient = secnum.array(np.zeros(n_features), integral=False)
    dot_product= X_shared @ weights.T
    # Compute approximated sigmoid using relu plus
    d_0 = dot_product < 0.5  
    d_1 = dot_product > 0.5 

    sigmoid = d_1 + (1 - d_0) * (1 - d_1) * (dot_product + 0.5)
    gradient = (sigmoid - y_shared) @ X_shared
    return gradient

def update_weights(weights, gradient, alpha,n_features,n_samples):
    # Update weights
    weights = weights - alpha * gradient
    return weights

def predict(X_shared, weights,n_samples):
    # Predict
    y_pred = secnum.array(np.zeros(n_samples), integral=False)
    dot_product= X_shared @ weights.T
    # Compute approximated sigmoid using relu plus
    d_0 = dot_product < 0.5  
    d_1 = dot_product > 0.5 

    sigmoid = d_1 + (1 - d_0) * (1 - d_1) * (dot_product + 0.5)
    y_pred = sigmoid > 0.5
    return y_pred

def compute_accuracy(y_pred, y_shared,n_samples):
    # Compute accuracy
    y_pred =np.array(y_pred)
    y_shared = np.array(y_shared)
    accuracy = np.sum(y_pred == y_shared) / n_samples
    return accuracy

async def logistic_regression_example():
    print(
        "Classification (Logistic regression) with l1 penalty, with gradient descent method"
    )
    
    if len(sys.argv) > 2:
        n_samples = int(sys.argv[1])
        n_features = int(sys.argv[2])
    else:
        print("Usage: python experiment.py <n_samples> <n_features>")
    alpha = 0.1

    #use dummy input data
    X=np.ones((n_samples, n_features))
    y=np.ones(n_samples)
    #X_mpc, y_mpc = get_mpc_data(X, y)
    X_mpc = secnum.array(X)
    y_mpc = secnum.array(y)
    await mpc.start()
    # Perform training step of logistic regression
    weights= training(X_mpc, y_mpc, alpha, n_features,n_samples)
    #y_pred = predict(X_mpc, weights,n_samples)
    #y_pred = await mpc.output(y_pred)
    #accuracy = compute_accuracy(y_pred, y,n_samples)
    
    #print("Accuracy: ", accuracy)
    await mpc.shutdown()

   


if __name__ == "__main__":
    mpc.run(logistic_regression_example())