import 'dart:math' show Random;

/// 与 Kotlin `kotlin.random.Random(seed)`（XorWowRandom）输出序列完全一致的伪随机数生成器。
///
/// 用于保证 Flutter 与安卓端输入相同种子时生成完全相同的棋局。
/// 算法移植自 Kotlin 标准库 `kotlin.random.XorWowRandom` 与
/// `kotlin.random.Random.nextInt(from, until)`（Marsaglia xorwow）。
class KotlinRandom implements Random {
  late int _x;
  late int _y;
  late int _z;
  late int _w;
  late int _v;
  late int _addend;

  /// 对应 Kotlin `Random(seed) = XorWowRandom(seed, seed.shr(31))`，
  /// 并在构造时丢弃前 64 个输出。
  KotlinRandom(int seed) {
    final int s1 = seed & 0xFFFFFFFF;
    final int s2 = (seed & 0x80000000) != 0 ? 0xFFFFFFFF : 0; // seed.shr(31)
    _x = s1;
    _y = s2;
    _z = 0;
    _w = 0;
    _v = (~s1) & 0xFFFFFFFF;
    _addend = (((s1 << 10) & 0xFFFFFFFF) ^ (s2 >>> 4)) & 0xFFFFFFFF;
    for (int i = 0; i < 64; i++) {
      _nextInt32();
    }
  }

  /// 一次 32 位无符号整数输出（Kotlin XorWowRandom.nextInt()）。
  int _nextInt32() {
    var t = _x;
    t = t ^ (t >>> 2);
    _x = _y;
    _y = _z;
    _z = _w;
    final int v0 = _v;
    _w = v0;
    t = (t ^ ((t << 1) & 0xFFFFFFFF)) ^ v0 ^ ((v0 << 4) & 0xFFFFFFFF);
    t &= 0xFFFFFFFF;
    _v = t;
    _addend = (_addend + 362437) & 0xFFFFFFFF;
    return (t + _addend) & 0xFFFFFFFF;
  }

  /// 对应 Kotlin nextBits(bitCount) = nextInt().takeUpperBits(bitCount)。
  int _nextBits(int bitCount) {
    final int v = _nextInt32();
    if (bitCount <= 0) return 0;
    if (bitCount >= 32) return v;
    return v >>> (32 - bitCount);
  }

  @override
  int nextInt(int max) {
    // Kotlin: nextInt(until) = nextInt(0, until)；2 的幂走 nextBits，否则拒绝采样
    final int n = max;
    if ((n & -n) == n) {
      final int bitCount = 31 - _leadingZeros32(n);
      return _nextBits(bitCount);
    }
    while (true) {
      final int bits = _nextInt32() >>> 1; // ushr(1)：恒为非负
      final int v = bits % n;
      if (bits - v + (n - 1) >= 0) return v;
    }
  }

  @override
  double nextDouble() {
    // Kotlin: (nextBits(26) * 2^-26) + (nextBits(27) * 2^-52)
    return ((_nextBits(26) << 26) + _nextBits(27)) / (1 << 52);
  }

  @override
  bool nextBool() {
    return (_nextInt32() & 1) != 0;
  }

  int _leadingZeros32(int n) => 32 - n.bitLength;
}