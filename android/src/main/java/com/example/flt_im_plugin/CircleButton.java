package com.example.flt_im_plugin;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Rect;
import android.graphics.drawable.Drawable;
import android.graphics.drawable.GradientDrawable;
import android.graphics.drawable.StateListDrawable;
import android.util.AttributeSet;
import android.view.animation.AnimationUtils;
import androidx.appcompat.widget.AppCompatImageButton;
import android.widget.ImageView.ScaleType;

public class CircleButton extends AppCompatImageButton implements Rotatable {
    private static final int ANIMATION_SPEED = 270;
    private static int[] STATE_SET_DISABLED = new int[]{-16842910};
    private static int[] STATE_SET_NONE = new int[0];
    private static int[] STATE_SET_PRESSED = new int[]{16842919};
    private static int[] STATE_SET_SELECTED = new int[]{16842913};
    private long mAnimationEndTime;
    private long mAnimationStartTime;
    private boolean mClockwise;
    private int mCurrentDegree;
    private GradientDrawable mDisabled;
    private boolean mEnableAnimation;
    private GradientDrawable mNormal;
    private GradientDrawable mPressed;
    private GradientDrawable mSelected;
    private int mStartDegree;
    private int mTargetDegree;

    public CircleButton(Context context) {
        this(context, null);
    }

    public CircleButton(Context context, AttributeSet attrs) {
        super(context, attrs);
        this.mCurrentDegree = 0;
        this.mStartDegree = 0;
        this.mTargetDegree = 0;
        this.mClockwise = false;
        this.mEnableAnimation = true;
        this.mAnimationStartTime = 0;
        this.mAnimationEndTime = 0;
        init();
    }

    public CircleButton(Context context, AttributeSet attrs, int defStyle) {
        super(context, attrs, defStyle);
        this.mCurrentDegree = 0;
        this.mStartDegree = 0;
        this.mTargetDegree = 0;
        this.mClockwise = false;
        this.mEnableAnimation = true;
        this.mAnimationStartTime = 0;
        this.mAnimationEndTime = 0;
        init();
    }

    public void setStroke(int width, int color) {
        this.mNormal.setStroke(width, color);
        this.mPressed.setStroke(width, color);
        this.mSelected.setStroke(width, color);
    }

    public void setBackgroundNormalColor(int color) {
        this.mNormal.setColor(color);
    }

    public void setBackgroundPressedColor(int color) {
        this.mPressed.setColor(color);
    }

    public void setBackgroundSelectedColor(int color) {
        this.mSelected.setColor(color);
    }

    public void setBackgroundDisabledColor(int color) {
        this.mDisabled.setColor(color);
    }

    public void setDisabledStroke(int width, int color) {
        this.mDisabled.setStroke(width, color);
    }

    public void setPressedStroke(int width, int color) {
        this.mPressed.setStroke(width, color);
    }

    public void setSelectedStroke(int width, int color) {
        this.mSelected.setStroke(width, color);
    }

    protected int getDegree() {
        return this.mTargetDegree;
    }

    public void setOrientation(int degree, boolean animation) {
        boolean z = true;
        this.mEnableAnimation = animation;
        degree = degree >= 0 ? degree % 360 : (degree % 360) + 360;
        if (degree != this.mTargetDegree) {
            this.mTargetDegree = degree;
            if (this.mEnableAnimation) {
                this.mStartDegree = this.mCurrentDegree;
                this.mAnimationStartTime = AnimationUtils.currentAnimationTimeMillis();
                int diff = this.mTargetDegree - this.mCurrentDegree;
                boolean clockwise;
                if (diff == 180) {
                    clockwise = true;
                } else {
                    clockwise = false;
                }
                if (diff < 0) {
                    diff += 360;
                }
                if (diff > 180) {
                    diff -= 360;
                }
                if ((diff < 0 || diff >= 180) && !clockwise) {
                    z = false;
                }
                this.mClockwise = z;
                this.mAnimationEndTime = this.mAnimationStartTime + ((long) ((Math.abs(diff) * 1000) / ANIMATION_SPEED));
            } else {
                this.mCurrentDegree = this.mTargetDegree;
            }
            invalidate();
        }
    }

    protected void onDraw(Canvas canvas) {
        Drawable drawable = getDrawable();
        if (drawable != null) {
            Rect bounds = drawable.getBounds();
            int w = bounds.right - bounds.left;
            int h = bounds.bottom - bounds.top;
            if (w != 0 && h != 0) {
                if (this.mCurrentDegree != this.mTargetDegree) {
                    long time = AnimationUtils.currentAnimationTimeMillis();
                    if (time < this.mAnimationEndTime) {
                        int deltaTime = (int) (time - this.mAnimationStartTime);
                        int i = this.mStartDegree;
                        if (!this.mClockwise) {
                            deltaTime = -deltaTime;
                        }
                        int degree = i + ((deltaTime * ANIMATION_SPEED) / 1000);
                        this.mCurrentDegree = degree >= 0 ? degree % 360 : (degree % 360) + 360;
                        invalidate();
                    } else {
                        this.mCurrentDegree = this.mTargetDegree;
                    }
                }
                int left = getPaddingLeft();
                int top = getPaddingTop();
                int width = (getWidth() - left) - getPaddingRight();
                int height = (getHeight() - top) - getPaddingBottom();
                int saveCount = canvas.getSaveCount();
                if (getScaleType() == ScaleType.FIT_CENTER && (width < w || height < h)) {
                    float ratio = Math.min(((float) width) / ((float) w), ((float) height) / ((float) h));
                    canvas.scale(ratio, ratio, ((float) width) / 2.0f, ((float) height) / 2.0f);
                }
                canvas.translate((float) ((width / 2) + left), (float) ((height / 2) + top));
                canvas.rotate((float) (-this.mCurrentDegree));
                canvas.translate((float) ((-w) / 2), (float) ((-h) / 2));
                drawable.draw(canvas);
                canvas.restoreToCount(saveCount);
            }
        }
    }

    private void init() {
        this.mNormal = new GradientDrawable();
        this.mNormal.setShape(1);
        this.mPressed = new GradientDrawable();
        this.mPressed.setShape(1);
        this.mSelected = new GradientDrawable();
        this.mSelected.setShape(1);
        this.mDisabled = new GradientDrawable();
        this.mDisabled.setShape(1);
        StateListDrawable background = new StateListDrawable();
        background.addState(STATE_SET_DISABLED, this.mDisabled);
        background.addState(STATE_SET_PRESSED, this.mPressed);
        background.addState(STATE_SET_SELECTED, this.mSelected);
        background.addState(STATE_SET_NONE, this.mNormal);
        setBackgroundDrawable(background);
    }
}
