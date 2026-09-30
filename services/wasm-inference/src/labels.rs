//! ImageNet 1k Class Labels & Ranking for WebAssembly
use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct Prediction {
    pub class_id: usize,
    pub label: String,
    pub probability: f32,
    pub confidence_percent: f32,
}

pub fn softmax_and_top_k(logits: &[f32], labels: &[String], top_k: usize) -> Vec<Prediction> {
    if logits.is_empty() {
        return Vec::new();
    }

    let max_val = logits.iter().cloned().fold(f32::NEG_INFINITY, f32::max);
    let mut exps = vec![0.0f32; logits.len()];
    let mut sum_exp = 0.0f32;

    for (i, &val) in logits.iter().enumerate() {
        let e = (val - max_val).exp();
        exps[i] = e;
        sum_exp += e;
    }

    let mut indexed_probs: Vec<(usize, f32)> = exps
        .iter()
        .enumerate()
        .map(|(i, &e)| (i, e / sum_exp))
        .collect();

    indexed_probs.sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap_or(std::cmp::Ordering::Equal));

    indexed_probs
        .into_iter()
        .take(top_k)
        .map(|(idx, prob)| {
            let label = if idx < labels.len() {
                labels[idx].clone()
            } else {
                format!("class_{}", idx)
            };
            Prediction {
                class_id: idx,
                label,
                probability: prob,
                confidence_percent: (prob * 10000.0).round() / 100.0,
            }
        })
        .collect()
}
