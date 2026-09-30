//! Image Preprocessing for MobileNetV2 in WebAssembly
//! Normalizes RGB input tensors to [1, 3, 224, 224] layout.

use image::{imageops::FilterType, GenericImageView};
use std::io::Cursor;

pub const INPUT_WIDTH: u32 = 224;
pub const INPUT_HEIGHT: u32 = 224;
pub const NUM_CHANNELS: usize = 3;
pub const TENSOR_SIZE: usize = (NUM_CHANNELS * (INPUT_WIDTH as usize) * (INPUT_HEIGHT as usize));

// ImageNet Mean and Standard Deviation
const MEAN: [f32; 3] = [0.485, 0.456, 0.406];
const STD: [f32; 3] = [0.229, 0.224, 0.225];

/// Preprocesses raw JPEG/PNG image bytes into a flattened [3, 224, 224] float32 tensor
pub fn preprocess_image(image_bytes: &[u8]) -> Result<Vec<f32>, String> {
    let img = image::load(Cursor::new(image_bytes), image::ImageFormat::Jpeg)
        .or_else(|_| image::load(Cursor::new(image_bytes), image::ImageFormat::Png))
        .map_err(|e| format!("Failed to decode image: {}", e))?;

    let (width, height) = img.dimensions();

    // Scale shortest side to 256
    let (new_w, new_h) = if width < height {
        (256, (height as f64 * 256.0 / width as f64) as u32)
    } else {
        ((width as f64 * 256.0 / height as f64) as u32, 256)
    };

    let resized = img.resize_exact(new_w, new_h, FilterType::Triangle);

    // Center crop to 224x224
    let crop_x = (new_w - INPUT_WIDTH) / 2;
    let crop_y = (new_h - INPUT_HEIGHT) / 2;
    let cropped = resized.crop_imm(crop_x, crop_y, INPUT_WIDTH, INPUT_HEIGHT);

    let plane_size = (INPUT_WIDTH * INPUT_HEIGHT) as usize;
    let mut tensor = vec![0.0f32; TENSOR_SIZE];

    for y in 0..INPUT_HEIGHT {
        for x in 0..INPUT_WIDTH {
            let pixel = cropped.get_pixel(x, y);
            let idx = (y * INPUT_WIDTH + x) as usize;

            let r = pixel[0] as f32 / 255.0;
            let g = pixel[1] as f32 / 255.0;
            let b = pixel[2] as f32 / 255.0;

            // Planar format: RRR... GGG... BBB...
            tensor[idx] = (r - MEAN[0]) / STD[0];
            tensor[plane_size + idx] = (g - MEAN[1]) / STD[1];
            tensor[2 * plane_size + idx] = (b - MEAN[2]) / STD[2];
        }
    }

    Ok(tensor)
}
