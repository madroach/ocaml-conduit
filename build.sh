#!/bin/sh -e

TAGS=principal,annot,bin_annot,short_paths,thread,strict_sequence
J_FLAG=2

BASE_PKG="sexplib ipaddr cstruct uri stringext"
SYNTAX_PKG="camlp4.macro sexplib.syntax"

# The Async backend is only supported in OCaml 4.01.0+
OCAML_VERSION=`ocamlc -version`
case $OCAML_VERSION in
4.00.*|3.*)
  echo Async backend only supported in OCaml 4.01.0 or higher
  ;;
*)
HAVE_ASYNC=`ocamlfind query async 2>/dev/null || true`
HAVE_ASYNC_SSL=`ocamlfind query async_ssl 2>/dev/null || true`
;;
esac

HAVE_LWT=`ocamlfind query lwt 2>/dev/null || true`
HAVE_LWT_SSL=`ocamlfind query lwt.ssl 2>/dev/null || true`
HAVE_MIRAGE=`ocamlfind query mirage-types dns.mirage tcpip 2>/dev/null || true`
HAVE_VCHAN=`ocamlfind query vchan 2>/dev/null || true`
HAVE_VCHAN_LWT=`ocamlfind query vchan.lwt xen-evtchn.unix 2>/dev/null || true`

add_target () {
  TARGETS="$TARGETS lib/$1.cmxs lib/$1.cma lib/$1.cmxa"
}

add_pkg () {
  PKG="$PKG $1"
}

add_pkg "$SYNTAX_PKG"
add_pkg "$BASE_PKG"
add_target "conduit"
rm -f _tags

echo 'true: syntax(camlp4o)' >> _tags

if [ "$HAVE_ASYNC" != "" ]; then
  echo "Building with Async support."
  echo "# This file is autogenerated by build.sh" > lib/conduit-async.mllib
  echo Conduit_async >> lib/conduit-async.mllib
  add_target "conduit-async"
  ASYNC_REQUIRES="async ipaddr.unix"

  if [ "$HAVE_ASYNC_SSL" != "" ]; then
    echo "Building with Async/SSL support."
    echo 'true: define(HAVE_ASYNC_SSL)' >> _tags
    ASYNC_REQUIRES="$ASYNC_REQUIRES async_ssl"
    echo Conduit_async_net_ssl >> lib/conduit-async.mllib
  fi
  cp lib/conduit-async.mllib lib/conduit-async.odocl
fi

if [ "$HAVE_LWT" != "" ]; then
  echo "Building with Lwt support."
  echo "# This file is autogenerated by build.sh" > lib/conduit-lwt.mllib
  echo Conduit_resolver_lwt > lib/conduit-lwt.mllib
  add_target "conduit-lwt"
  LWT_REQUIRES="lwt"
  LWT_UNIX_REQUIRES="lwt.unix ipaddr.unix uri.services"

  echo Conduit_lwt_unix > lib/conduit-lwt-unix.mllib
  echo Conduit_lwt_unix_net >> lib/conduit-lwt-unix.mllib
  echo Conduit_resolver_lwt_unix >> lib/conduit-lwt-unix.mllib
  add_target "conduit-lwt-unix"

  if [ "$HAVE_LWT_SSL" != "" ]; then
    echo "Building with Lwt/SSL support."
    echo 'true: define(HAVE_LWT_SSL)' >> _tags
    LWT_UNIX_REQUIRES="$LWT_UNIX_REQUIRES lwt.ssl"
    echo Conduit_lwt_unix_net_ssl >> lib/conduit-lwt-unix.mllib
  fi

  cp lib/conduit-lwt.mllib lib/conduit-lwt.odocl
  cp lib/conduit-lwt-unix.mllib lib/conduit-lwt-unix.odocl

  if [ "$HAVE_MIRAGE" != "" ]; then
    echo "Building with Mirage support."
    echo 'true: define(HAVE_MIRAGE)' >> _tags
    echo Conduit_mirage > lib/conduit-lwt-mirage.mllib
    echo Conduit_resolver_mirage >> lib/conduit-lwt-mirage.mllib
    LWT_MIRAGE_REQUIRES="mirage-types dns.mirage uri.services"
    if [ "$HAVE_VCHAN" != "" ]; then
      LWT_MIRAGE_REQUIRES="$LWT_MIRAGE_REQUIRES vchan"
    fi
    add_target "conduit-lwt-mirage"
    cp lib/conduit-lwt-mirage.mllib lib/conduit-lwt-mirage.odocl
  fi

fi

if [ "$HAVE_VCHAN" ]; then
  echo "Build with Vchan support."
  echo 'true: define(HAVE_VCHAN)' >> _tags
fi 

if [ "$HAVE_VCHAN_LWT" != "" ]; then
    echo "Building with Vchan Lwt_unix support."
    echo 'true: define(HAVE_VCHAN_LWT)' >> _tags
    VCHAN_LWT_REQUIRES="vchan.lwt"
fi

# Build all the ocamldoc
rm -f lib/conduit-all.odocl
cat lib/*.odocl > lib/conduit-all.odocl
TARGETS="${TARGETS} lib/conduit-all.docdir/index.html"

REQS=`echo $PKG $ASYNC_REQUIRES $LWT_REQUIRES $LWT_UNIX_REQUIRES $LWT_MIRAGE_REQUIRES $VCHAN_LWT_REQUIRES | tr -s ' '`

ocamlbuild -use-ocamlfind -j ${J_FLAG} -tag ${TAGS} \
  -cflags "-w A-4-33-40-41-42-43-34-44" \
  -pkgs `echo $REQS | tr ' ' ','` \
  ${TARGETS}

sed \
  -e "s/@BASE_REQUIRES@/${BASE_PKG}/g" \
  -e "s/@VERSION@/`cat VERSION`/g" \
  -e "s/@ASYNC_REQUIRES@/${ASYNC_REQUIRES}/g" \
  -e "s/@LWT_REQUIRES@/${LWT_REQUIRES}/g" \
  -e "s/@LWT_UNIX_REQUIRES@/${LWT_UNIX_REQUIRES}/g" \
  -e "s/@LWT_MIRAGE_REQUIRES@/${LWT_MIRAGE_REQUIRES}/g" \
  -e "s/@VCHAN_LWT_REQUIRES@/${VCHAN_LWT_REQUIRES}/g" \
  META.in > META

if [ "$1" = "true" ]; then
  B=_build/lib/
  ocamlfind remove conduit || true
  FILES=`ls -1 $B/*.cmi $B/*.cmt $B/*.cmti $B/*.cmx $B/*.cmxa $B/*.cma $B/*.cmxs $B/*.a 2>/dev/null || true`
  ocamlfind install conduit META $FILES
fi
