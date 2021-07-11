package com.example.flt_im_plugin;

import android.graphics.drawable.Drawable;
import android.os.Handler;
import android.view.View;
import android.view.ViewGroup.LayoutParams;
import android.view.animation.AnimationUtils;

public class CallIncomingAnimation {
    public static int ENDLESS = -1;
    private static final int FRAME_TIME = 10;
    private static Handler sHandler = new Handler();
    private Drawable mDrawable;
    private int mDuration;
    private int mFrequency;
    private boolean mIsAnimating = false;
    private int mMax;
    private int mMin;
    private Runnable mScaleRunnable;
    private long mStartTime;
    private View mView;

    public CallIncomingAnimation(int min, int max, int duration) {
        this.mMin = min;
        this.mMax = max;
        this.mDuration = duration;
        this.mScaleRunnable = new Runnable() {
            public void run() {
                long time = AnimationUtils.currentAnimationTimeMillis() - CallIncomingAnimation.this.mStartTime;
                if (time <= ((long) CallIncomingAnimation.this.mDuration)) {
                    CallIncomingAnimation.this.setWidth(CallIncomingAnimation.this.getWidthAtTime(time));
                    CallIncomingAnimation.sHandler.postDelayed(CallIncomingAnimation.this.mScaleRunnable, 10);
                    return;
                }
                CallIncomingAnimation.this.mFrequency = CallIncomingAnimation.this.mFrequency - 1;
                if (CallIncomingAnimation.this.mFrequency == 0) {
                    CallIncomingAnimation.this.mView.setVisibility(4);
                    CallIncomingAnimation.this.mIsAnimating = false;
                    return;
                }
                CallIncomingAnimation.this.performAnimation();
            }
        };
    }

    public void startAnimation(View view, int frequency) {
        this.mView = view;
        this.mFrequency = frequency;
        setWidth(getWidthAtTime(0));
        this.mView.setVisibility(0);
        this.mDrawable = view.getBackground();
        performAnimation();
    }

    public void startAnimation(View view) {
        startAnimation(view, 1);
    }

    private int getWidthAtTime(long time) {
        return (int) (((((float) (this.mMax - this.mMin)) / ((float) this.mDuration)) * ((float) time)) + ((float) this.mMin));
    }

    private void performAnimation() {
        this.mIsAnimating = true;
        this.mStartTime = AnimationUtils.currentAnimationTimeMillis();
        sHandler.post(this.mScaleRunnable);
    }

    public void setWidth(int width) {
        LayoutParams params = this.mView.getLayoutParams();
        params.width = width;
        this.mView.setLayoutParams(params);
    }

    public void setAlpha(int alpha) {
        this.mDrawable.setAlpha(alpha);
    }

    public boolean isAnimating() {
        return this.mIsAnimating;
    }

    public void stop() {
        sHandler.removeCallbacks(this.mScaleRunnable);
        if (this.mView != null) {
            this.mView.setVisibility(4);
        }
        this.mIsAnimating = false;
    }

    public void destroy() {
        stop();
        this.mScaleRunnable = null;
        this.mDrawable = null;
    }
}
