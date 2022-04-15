package com.example.flt_im_plugin;

import android.annotation.TargetApi;
import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Matrix;
import android.graphics.Rect;
import android.os.Build.VERSION;
import android.util.AttributeSet;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewGroup;
import android.view.ViewParent;

public class RotateLayout extends ViewGroup implements Rotatable {
    private static final String TAG = "RotateLayout";
    protected View mChild;
    private Matrix mMatrix = new Matrix();
    private int mOrientation;

    public RotateLayout(Context context, AttributeSet attrs) {
        super(context, attrs);
        //setBackgroundResource(17170445);
    }

    @TargetApi(11)
    protected void onFinishInflate() {
        super.onFinishInflate();
        this.mChild = getChildAt(0);
        if (hasViewTransformProperties()) {
            this.mChild.setPivotX(0.0f);
            this.mChild.setPivotY(0.0f);
        }
    }

    protected void onLayout(boolean change, int left, int top, int right, int bottom) {
        int width = right - left;
        int height = bottom - top;
        switch (this.mOrientation) {
            case 0:
            case 180:
                this.mChild.layout(0, 0, width, height);
                return;
            case 90:
            case 270:
                this.mChild.layout(0, 0, height, width);
                return;
            default:
                return;
        }
    }

    public boolean dispatchTouchEvent(MotionEvent event) {
        if (!hasViewTransformProperties()) {
            int w = getMeasuredWidth();
            int h = getMeasuredHeight();
            switch (this.mOrientation) {
                case 0:
                    this.mMatrix.setTranslate(0.0f, 0.0f);
                    break;
                case 90:
                    this.mMatrix.setTranslate(0.0f, (float) (-h));
                    break;
                case 180:
                    this.mMatrix.setTranslate((float) (-w), (float) (-h));
                    break;
                case 270:
                    this.mMatrix.setTranslate((float) (-w), 0.0f);
                    break;
            }
            this.mMatrix.postRotate((float) this.mOrientation);
        }
        return super.dispatchTouchEvent(event);
    }

    protected void dispatchDraw(Canvas canvas) {
        if (hasViewTransformProperties()) {
            super.dispatchDraw(canvas);
            return;
        }
        canvas.save();
        int w = getMeasuredWidth();
        int h = getMeasuredHeight();
        switch (this.mOrientation) {
            case 0:
                canvas.translate(0.0f, 0.0f);
                break;
            case 90:
                canvas.translate(0.0f, (float) h);
                break;
            case 180:
                canvas.translate((float) w, (float) h);
                break;
            case 270:
                canvas.translate((float) w, 0.0f);
                break;
        }
        canvas.rotate((float) (-this.mOrientation), 0.0f, 0.0f);
        super.dispatchDraw(canvas);
        canvas.restore();
    }

    @TargetApi(11)
    protected void onMeasure(int widthSpec, int heightSpec) {
        int w = 0;
        int h = 0;
        switch (this.mOrientation) {
            case 0:
            case 180:
                measureChild(this.mChild, widthSpec, heightSpec);
                w = this.mChild.getMeasuredWidth();
                h = this.mChild.getMeasuredHeight();
                break;
            case 90:
            case 270:
                measureChild(this.mChild, heightSpec, widthSpec);
                w = this.mChild.getMeasuredHeight();
                h = this.mChild.getMeasuredWidth();
                break;
        }
        setMeasuredDimension(w, h);
        if (hasViewTransformProperties()) {
            switch (this.mOrientation) {
                case 0:
                    this.mChild.setTranslationX(0.0f);
                    this.mChild.setTranslationY(0.0f);
                    break;
                case 90:
                    this.mChild.setTranslationX(0.0f);
                    this.mChild.setTranslationY((float) h);
                    break;
                case 180:
                    this.mChild.setTranslationX((float) w);
                    this.mChild.setTranslationY((float) h);
                    break;
                case 270:
                    this.mChild.setTranslationX((float) w);
                    this.mChild.setTranslationY(0.0f);
                    break;
            }
            this.mChild.setRotation((float) (-this.mOrientation));
        }
    }

    public boolean shouldDelayChildPressedState() {
        return false;
    }

    public void setOrientation(int orientation, boolean animation) {
        orientation %= 360;
        if (this.mOrientation != orientation) {
            this.mOrientation = orientation;
            requestLayout();
        }
    }

    public int getOrientation() {
        return this.mOrientation;
    }

    public ViewParent invalidateChildInParent(int[] location, Rect r) {
        if (!(hasViewTransformProperties() || this.mOrientation == 0)) {
            r.set(0, 0, getWidth(), getHeight());
        }
        return super.invalidateChildInParent(location, r);
    }

    private static boolean hasViewTransformProperties() {
        return VERSION.SDK_INT >= 11;
    }
}
