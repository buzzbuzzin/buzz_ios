//
//  SignatureCanvasView.swift
//  Buzz
//
//  Created for electronic signature capture
//

import SwiftUI
import PencilKit

struct SignatureCanvasView: View {
    @Binding var signatureImage: UIImage?
    @State private var canvasView = PKCanvasView()
    @State private var showClearConfirmation = false
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Sign Here")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 0) {
                SignatureCanvas(canvasView: $canvasView, signatureImage: $signatureImage)
                    .frame(height: 200)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 2)
                    )
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .accessibilityLabel("Signature drawing area")
                    .accessibilityHint("Draw your signature using your finger or Apple Pencil")
                
                // Clear button below signature area - show when signature exists
                if signatureImage != nil {
                    Button(action: {
                        showClearConfirmation = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "trash")
                                .font(.subheadline)
                            Text("Clear Signature")
                                .font(.subheadline)
                        }
                        .foregroundColor(.red)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .padding(.top, 8)
                }
            }
            
            Text("Draw your signature above using your finger or Apple Pencil")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .confirmationDialog("Clear Signature", isPresented: $showClearConfirmation) {
            Button("Clear Signature", role: .destructive) {
                clearSignature()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to clear your signature?")
        }
    }
    
    private func clearSignature() {
        canvasView.drawing = PKDrawing()
        signatureImage = nil
    }
}

// MARK: - UIViewRepresentable Canvas

private struct SignatureCanvas: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    @Binding var signatureImage: UIImage?
    
    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawingPolicy = .anyInput
        canvasView.tool = PKInkingTool(.pen, color: .black, width: 3)
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.delegate = context.coordinator
        return canvasView
    }
    
    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(signatureImage: $signatureImage, canvasView: $canvasView)
    }
    
    class Coordinator: NSObject, PKCanvasViewDelegate {
        @Binding var signatureImage: UIImage?
        @Binding var canvasView: PKCanvasView
        
        init(signatureImage: Binding<UIImage?>, canvasView: Binding<PKCanvasView>) {
            _signatureImage = signatureImage
            _canvasView = canvasView
        }
        
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            // Convert drawing to image
            let drawing = canvasView.drawing
            let image = drawing.image(from: drawing.bounds, scale: 2.0)
            signatureImage = image
        }
    }
}

