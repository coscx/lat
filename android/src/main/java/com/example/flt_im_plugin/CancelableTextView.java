package com.example.flt_im_plugin;

import android.annotation.SuppressLint;
import android.content.Context;
import android.graphics.drawable.Drawable;
import android.util.AttributeSet;
import android.view.MotionEvent;
import android.view.View;
import androidx.appcompat.widget.AppCompatTextView;

public class CancelableTextView extends AppCompatTextView {
    final int DRAWABLE_BOTTOM = 3;
    final int DRAWABLE_LEFT = 0;
    final int DRAWABLE_RIGHT = 2;
    final int DRAWABLE_TOP = 1;
    private DrawableRightListener mRightListener;

    public interface DrawableRightListener {
        void onDrawableRightClick(View view);
    }

    public CancelableTextView(Context context, AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
    }

    public CancelableTextView(Context context, AttributeSet attrs) {
        super(context, attrs);
    }

    public CancelableTextView(Context context) {
        super(context);
    }

    public void setDrawableRightListener(DrawableRightListener listener) {
        this.mRightListener = listener;
    }

    @SuppressLint({"ClickableViewAccessibility"})
    public boolean onTouchEvent(MotionEvent event) {
        switch (event.getAction()) {
            case 1:
                if (this.mRightListener != null) {
                    Drawable drawableRight = getCompoundDrawables()[2];
                    if (drawableRight != null && event.getX() > ((float) ((getWidth() - getPaddingRight()) - drawableRight.getIntrinsicWidth()))) {
                        this.mRightListener.onDrawableRightClick(this);
                        return true;
                    }
                }
                break;
        }
        return super.onTouchEvent(event);
    }
}
