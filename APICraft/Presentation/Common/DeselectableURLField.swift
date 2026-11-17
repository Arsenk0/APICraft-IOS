import SwiftUI
import UIKit

public struct DeselectableURLField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String = "https://api.example.com"
    var onCommit: (() -> Void)? = nil
    var onFocusChange: ((Bool) -> Void)? = nil
    
    public init(
        text: Binding<String>,
        placeholder: String = "https://api.example.com",
        onCommit: (() -> Void)? = nil,
        onFocusChange: ((Bool) -> Void)? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.onCommit = onCommit
        self.onFocusChange = onFocusChange
    }
    
    public func makeUIView(context: Context) -> CustomURLTextView {
        let textView = CustomURLTextView()
        textView.delegate = context.coordinator
        textView.placeholder = placeholder
        textView.text = text
        textView.updatePlaceholderVisibility()
        return textView
    }
    
    public func updateUIView(_ uiView: CustomURLTextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
            uiView.updatePlaceholderVisibility()
            uiView.invalidateIntrinsicContentSize()
        }
        uiView.placeholder = placeholder
        uiView.updateParentScrollViewReference()
    }
    
    public func sizeThatFits(_ proposal: ProposedViewSize, uiView: CustomURLTextView, context: Context) -> CGSize? {
        let width = proposal.width ?? 260
        let fittingHeight = uiView.calculatedContentHeight(for: width)
        let clampedHeight = max(34, min(fittingHeight, 86))
        return CGSize(width: width, height: clampedHeight)
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public class Coordinator: NSObject, UITextViewDelegate {
        var parent: DeselectableURLField
        
        init(_ parent: DeselectableURLField) {
            self.parent = parent
        }
        
        public func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            (textView as? CustomURLTextView)?.updatePlaceholderVisibility()
            textView.invalidateIntrinsicContentSize()
        }
        
        public func textViewDidBeginEditing(_ textView: UITextView) {
            parent.onFocusChange?(true)
        }
        
        public func textViewDidEndEditing(_ textView: UITextView) {
            parent.onFocusChange?(false)
            parent.onCommit?()
        }
    }
}

public final class CustomURLTextView: UITextView {
    var placeholder: String = "" {
        didSet {
            placeholderLabel.text = placeholder
        }
    }
    
    private weak var parentScrollView: UIScrollView?
    
    private let placeholderLabel: UILabel = {
        let label = UILabel()
        label.textColor = .placeholderText
        label.font = UIFont.monospacedSystemFont(ofSize: 13.5, weight: .medium)
        label.isUserInteractionEnabled = false
        return label
    }()
    
    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        font = UIFont.monospacedSystemFont(ofSize: 13.5, weight: .medium)
        backgroundColor = .clear
        textColor = .label
        autocorrectionType = .no
        autocapitalizationType = .none
        keyboardType = .asciiCapable
        isEditable = true
        isSelectable = true
        isUserInteractionEnabled = true
        isScrollEnabled = true
        showsVerticalScrollIndicator = true
        alwaysBounceVertical = false
        bounces = true
        textContainer.lineBreakMode = .byCharWrapping
        textContainer.lineFragmentPadding = 0
        textContainerInset = UIEdgeInsets(top: 6, left: 0, bottom: 6, right: 0)
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        addSubview(placeholderLabel)
    }
    
    public override func didMoveToWindow() {
        super.didMoveToWindow()
        updateParentScrollViewReference()
    }
    
    public override func didMoveToSuperview() {
        super.didMoveToSuperview()
        updateParentScrollViewReference()
    }
    
    func updateParentScrollViewReference() {
        var view: UIView? = superview
        while let v = view {
            if let sv = v as? UIScrollView, sv !== self {
                parentScrollView = sv
                break
            }
            view = v.superview
        }
    }
    
    func updatePlaceholderVisibility() {
        placeholderLabel.isHidden = !(text ?? "").isEmpty
    }
    
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        updateParentScrollViewReference()
        if contentSize.height > bounds.height + 2 {
            parentScrollView?.panGestureRecognizer.isEnabled = false
        }
        super.touchesBegan(touches, with: event)
    }
    
    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        parentScrollView?.panGestureRecognizer.isEnabled = true
        super.touchesEnded(touches, with: event)
    }
    
    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        parentScrollView?.panGestureRecognizer.isEnabled = true
        super.touchesCancelled(touches, with: event)
    }
    
    func calculatedContentHeight(for width: CGFloat) -> CGFloat {
        let padding = textContainer.lineFragmentPadding * 2 + textContainerInset.left + textContainerInset.right
        let availableWidth = max(20, width - padding)
        let currentText = text ?? ""
        let sampleText = currentText.isEmpty ? (placeholder.isEmpty ? "A" : placeholder) : currentText
        let textSize = (sampleText as NSString).boundingRect(
            with: CGSize(width: availableWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font ?? UIFont.monospacedSystemFont(ofSize: 13.5, weight: .medium)],
            context: nil
        ).size
        return ceil(textSize.height) + textContainerInset.top + textContainerInset.bottom
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        placeholderLabel.frame = CGRect(
            x: textContainerInset.left,
            y: textContainerInset.top,
            width: max(0, bounds.width - textContainerInset.left - textContainerInset.right),
            height: 20
        )
    }
    
    public override var intrinsicContentSize: CGSize {
        let width = bounds.width > 0 ? bounds.width : 260
        let fittingHeight = calculatedContentHeight(for: width)
        let clampedHeight = max(34, min(fittingHeight, 86))
        return CGSize(width: UIView.noIntrinsicMetric, height: clampedHeight)
    }
}
