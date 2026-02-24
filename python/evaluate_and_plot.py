import os
from pathlib import Path
import numpy as np
import yaml
import matplotlib.pyplot as plt
from sklearn.metrics import confusion_matrix, roc_curve, auc, precision_recall_curve, average_precision_score, ConfusionMatrixDisplay

# Local utilities
from train_mlp import MLP, discover_pairs, image_to_samples

HERE = Path(__file__).parent
ART = HERE / "artifacts"
PLOTS = ART / "plots"


def load_cfg():
    with open(HERE / "config.yaml", "r") as f:
        return yaml.safe_load(f)


def load_model_from_artifacts(cfg):
    mdl = MLP(3, cfg["model"]["hidden"], 2, cfg["model"]["activation"])
    W1 = np.load(ART / "W1.npy"); b1 = np.load(ART / "b1.npy")
    W2 = np.load(ART / "W2.npy"); b2 = np.load(ART / "b2.npy")
    mdl.W1, mdl.b1, mdl.W2, mdl.b2 = W1, b1, W2, b2
    return mdl


def evaluate(mdl, X, y):
    z, _ = mdl.forward(X)
    p = mdl.softmax(z)
    y_hat = p.argmax(1)
    y_score = p[:, 1]

    cm = confusion_matrix(y, y_hat, labels=[0, 1])
    fpr, tpr, _ = roc_curve(y, y_score)
    roc_auc = auc(fpr, tpr)
    prec, rec, _ = precision_recall_curve(y, y_score)
    ap = average_precision_score(y, y_score)
    acc = (y_hat == y).mean()

    return {
        "cm": cm,
        "fpr": fpr,
        "tpr": tpr,
        "roc_auc": roc_auc,
        "prec": prec,
        "rec": rec,
        "ap": ap,
        "acc": acc,
    }


def plot_and_save(metrics):
    PLOTS.mkdir(parents=True, exist_ok=True)

    # Confusion Matrix
    fig_cm, ax_cm = plt.subplots(figsize=(4, 4))
    disp = ConfusionMatrixDisplay(confusion_matrix=metrics["cm"], display_labels=["Not Fire", "Fire"])
    disp.plot(cmap="Blues", ax=ax_cm, colorbar=False)
    ax_cm.set_title("Confusion Matrix (Val)")
    fig_cm.tight_layout()
    cm_path = PLOTS / "confusion_matrix.png"
    fig_cm.savefig(cm_path, dpi=150)
    plt.close(fig_cm)

    # ROC Curve
    fig_roc, ax_roc = plt.subplots(figsize=(5, 4))
    ax_roc.plot(metrics["fpr"], metrics["tpr"], label=f"ROC AUC = {metrics['roc_auc']:.3f}")
    ax_roc.plot([0, 1], [0, 1], "k--", alpha=0.5)
    ax_roc.set_xlabel("False Positive Rate")
    ax_roc.set_ylabel("True Positive Rate")
    ax_roc.set_title("ROC Curve (Val)")
    ax_roc.legend(loc="lower right")
    fig_roc.tight_layout()
    roc_path = PLOTS / "roc_curve.png"
    fig_roc.savefig(roc_path, dpi=150)
    plt.close(fig_roc)

    # Precision-Recall Curve
    fig_pr, ax_pr = plt.subplots(figsize=(5, 4))
    ax_pr.plot(metrics["rec"], metrics["prec"], label=f"AP = {metrics['ap']:.3f}")
    ax_pr.set_xlabel("Recall")
    ax_pr.set_ylabel("Precision")
    ax_pr.set_title("Precision-Recall (Val)")
    ax_pr.legend(loc="lower left")
    fig_pr.tight_layout()
    pr_path = PLOTS / "pr_curve.png"
    fig_pr.savefig(pr_path, dpi=150)
    plt.close(fig_pr)

    return {
        "cm": str(cm_path),
        "roc": str(roc_path),
        "pr": str(pr_path),
    }


def main():
    cfg = load_cfg()
    # Ensure dataset root is absolute (config may contain a relative path)
    ds_root = Path(cfg["dataset"]["root"])
    if not ds_root.is_absolute():
        cfg["dataset"]["root"] = str((HERE / ds_root).resolve())
    # Build a robust validation set without relying on build_dataset (handles edge cases when val split is empty)
    pairs = discover_pairs(cfg)
    if len(pairs) == 0:
        raise RuntimeError("No image pairs discovered. Please verify dataset paths in config.yaml")
    split = int(0.8 * len(pairs))
    val_pairs = pairs[split:] if split < len(pairs) else pairs
    Xs, ys = [], []
    for img_path, mask_path, is_fire in val_pairs:
        X, y = image_to_samples(img_path, mask_path, cfg["dataset"]["samples_per_image"], is_fire)
        if X.size == 0:
            continue
        Xs.append(X); ys.append(y)
    if not Xs:
        raise RuntimeError("Validation sampling produced no data. Consider lowering samples_per_image or checking images/masks.")
    Xva = np.vstack(Xs); yva = np.concatenate(ys)
    mdl = load_model_from_artifacts(cfg)
    metrics = evaluate(mdl, Xva, yva)

    print(f"Validation accuracy: {metrics['acc']*100:.2f}%")
    print(f"ROC AUC: {metrics['roc_auc']:.4f}")
    print(f"Average Precision (AP): {metrics['ap']:.4f}")

    out_paths = plot_and_save(metrics)
    print("Saved plots:")
    for k, v in out_paths.items():
        print(f"  {k}: {v}")


if __name__ == "__main__":
    main()
