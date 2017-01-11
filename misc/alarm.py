import matplotlib.pyplot as plt
import numpy
import scipy.io.wavfile
import math

SAMPLE_RATE = 44100
FREQUENCY_TONE = 4096
TIME_BEEP_ON = 0.1
TIME_BEEP_OFF = 0.05
TIME_BEEP_PAUSE = 0.25

# Calculate timings in terms of number of samples
num_beep_on_samples = int(math.ceil(TIME_BEEP_ON*SAMPLE_RATE))
num_beep_off_samples = int(math.ceil(TIME_BEEP_OFF*SAMPLE_RATE))
num_beep_pause_samples = int(math.ceil(TIME_BEEP_PAUSE*SAMPLE_RATE))
num_period_samples = int(math.ceil(SAMPLE_RATE/FREQUENCY_TONE))

# Calculate timings at 4 kHz
print("Beep On:     {:3f} sec, {} samples @ 4096 Hz".format(TIME_BEEP_ON, math.floor(FREQUENCY_TONE*TIME_BEEP_ON + 0.5)))
print("Beep Off:    {:3f} sec, {} samples @ 4096 Hz".format(TIME_BEEP_OFF, math.floor(FREQUENCY_TONE*TIME_BEEP_OFF + 0.5)))
print("Beep Pause:  {:3f} sec, {} samples @ 4096 Hz".format(TIME_BEEP_PAUSE, math.floor(FREQUENCY_TONE*TIME_BEEP_PAUSE + 0.5)))
print("")

# Dump timings
print("Beep On:     {:3f} sec, {} samples @ 44100 Hz".format(TIME_BEEP_ON, num_beep_on_samples))
print("Beep Off:    {:3f} sec, {} samples @ 44100 Hz".format(TIME_BEEP_OFF, num_beep_off_samples))
print("Beep Pause:  {:3f} sec, {} samples @ 44100 Hz".format(TIME_BEEP_PAUSE, num_beep_pause_samples))
print("Tone:        {:f} sec, {} samples @ 44100 Hz".format(1/FREQUENCY_TONE, num_period_samples))


samples = []

# Generate 3 beeps
for _ in range(3):
    j = 0
    # Create square wave with period num_period_samples
    # for up to num_beep_on_samples
    while j < num_beep_on_samples:
        samples += [1.0]*(num_period_samples//2)
        samples += [-1.0]*(num_period_samples//2)
        j += num_period_samples
    
    # Create pause between beep
    samples += [0.0]*num_beep_off_samples

# Add pause
samples += [0.0]*num_beep_pause_samples

# Replicate sequence 10 times
samples = samples*10

# Plot sequence
plt.plot(samples)
plt.show()

# Create wave file
scipy.io.wavfile.write("alarm.wav", SAMPLE_RATE, numpy.array(samples))
