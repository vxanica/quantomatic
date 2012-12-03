package quanto.data

import collection.immutable.TreeSet

// basically a map, but with cached inverse images
class PFun[A,B]
  (val f : Map[A,B], val finv: Map[B,TreeSet[A]])
  (implicit keyOrd: Ordering[A]) extends Iterable[(A,B)] {

  // children have the option to override this to give a default value
  def default(key: A): B =
    throw new NoSuchElementException("key not found: " + key)

  def -(k: A) = {
    val v = f(k)
    val finv1 =
      if (finv(v).size == 1) finv - v
      else finv + (v -> (finv(v) - k))
    new PFun[A,B](f - k,finv1)
  }


  def +(kv: (A,B)) : PFun[A,B] = {
    val finv1 =
      (f.get(kv._1) match {
        case Some(oldV) => if (finv(oldV).size == 1) finv - oldV
                           else finv + (oldV -> (finv(oldV) - kv._1))
        case None => finv
      }) + (kv._2 -> (finv.getOrElse(kv._2, TreeSet[A]()) + kv._1))
    new PFun(f + kv,finv1)
  }

  def get(k: A) = f.get(k)
  def apply(k: A) = f.get(k) match {
    case Some(v) => v
    case None => default(k)
  }
  def inv(v: B): Set[A] = {
    finv.get(v) match {
      case Some(s) => s
      case None => Set()
    }
  }

  def dom = f.keys

  def iterator = f.iterator

  // PFun inherits equality from its member "f"
  override def hashCode = f.hashCode()

  override def canEqual(other: Any) = other match {
    case that: PFun[_,_] => true
    case _ => false
  }

  override def equals(other: Any) = other match {
    case that: PFun[_,_] => (that canEqual this) && (f == that.f)
    case _ => false
  }
}

object PFun {
  def apply[A,B](kvs: (A,B)*)(implicit keyOrd: Ordering[A]) : PFun[A,B] = {
    kvs.foldLeft(new PFun[A,B](Map(),Map())){ (pf: PFun[A,B], kv: (A,B)) => pf + kv }
  }
}

