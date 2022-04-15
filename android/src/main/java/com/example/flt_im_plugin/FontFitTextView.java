package com.example.flt_im_plugin;

import android.content.Context;
import android.graphics.Paint;
import android.util.AttributeSet;
import android.view.View.MeasureSpec;
import android.widget.TextView;

import androidx.appcompat.widget.AppCompatTextView;

public class FontFitTextView extends AppCompatTextView {
    private float mHi;
    private float mLo;
    private Paint mTestPaint;

    public FontFitTextView(Context context) {
        super(context);
        initialise(context);
    }

    public FontFitTextView(Context context, AttributeSet attrs) {
        super(context, attrs);
        initialise(context);
    }

    private void initialise(Context context) {
        this.mTestPaint = new Paint();
        this.mHi = getPaint().getTextSize();
        setSingleLine(true);
        this.mTestPaint.set(getPaint());
        this.mLo = (float) ((int) ((20.0f * context.getResources().getDisplayMetrics().scaledDensity) + 0.5f));
    }

    private void refitText(String text, int textWidth) {
        if (textWidth > 0) {
            int targetWidth = (textWidth - getPaddingLeft()) - getPaddingRight();
            float hi = this.mHi;
            float lo = this.mLo;
            this.mTestPaint.set(getPaint());
            while (hi - lo > 0.5f) {
                float size = (hi + lo) / 2.0f;
                this.mTestPaint.setTextSize(size);
                if (this.mTestPaint.measureText(text) >= ((float) targetWidth)) {
                    hi = size;
                } else {
                    lo = size;
                }
            }
            setTextSize(0, lo);
        }
    }

    protected void onMeasure(int widthMeasureSpec, int heightMeasureSpec) {
        super.onMeasure(widthMeasureSpec, heightMeasureSpec);
        int parentWidth = MeasureSpec.getSize(widthMeasureSpec);
        int height = getMeasuredHeight();
        refitText(getText().toString(), parentWidth);
        setMeasuredDimension(parentWidth, height);
    }

    protected void onTextChanged(CharSequence text, int start, int before, int after) {
        refitText(text.toString(), getWidth());
    }

    protected void onSizeChanged(int w, int h, int oldw, int oldh) {
        if (w != oldw) {
            refitText(getText().toString(), w);
        }
    }

    public boolean canScrollHorizontally(int direction) {
        return false;
    }
}
