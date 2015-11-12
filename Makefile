#-------------------------------------------------------------------------------
# Makefile - This is a smart C++ Makefile, with auto-dependencies.
# -----------------
# Begin				: 01.11.2012
# Copyright			: (C) 2012 - 2015
#
# 					        ++++++++++++++++++
# 					         Martin WETTERWALD
# 					        ++++++++++++++++++

#-------------------------------------------------------------------------------
#
# My work is based on research in http://www.gnu.org/software/make/manual/, and
# the manual of each shell function I use.
#
# A future release of this Makefile will include and better static
# and dynamic librairies management.
#
# The aim will be to have one version of this Makefile in the hard disk drive,
# without need to copy it to only change some variables.
#
# If you need any explanation, feel free to contact me.
#
#-------------------------------------------------------------------------------


#--------VARIABLES--------#
#--MAKEFILE NAME, EXE NAME & FOLDERS OF TARGETS--#
THIS = $(lastword $(MAKEFILE_LIST)) #This variable must stay at the top
MKCONFIG = mk.conf.ini
MAKEFILEADDONS = mk.addons
ifeq ($(wildcard $(MKCONFIG)),)
$(error "Create the $(MKCONFIG) file and configure it first.")
endif
THIS += $(MKCONFIG)
ifneq ($(wildcard $(MAKEFILEADDONS)),)
THIS += $(MAKEFILEADDONS)
endif

#This makefile function can read the $(MKCONFIG) file. It respects the
#.ini syntax.
#It takes 2 parameters:
#- the first one is the name of the section (for [mySampleSection], enter
#mySampleSection)
#- the second one is the name of the variable in that section
#- It returns the value of that variable, or an empty string if the section or
#variable don't exist.
readConfig = $(shell sectionLine=`grep -E -n "^\[$1\][[:space:]]*$$" $(MKCONFIG) \
	| cut -d ':' -f 1`; \
sectionLine=`expr $$sectionLine + 1`; \
restOfFile=`tail -n +$$sectionLine $(MKCONFIG)`; \
nextSectionLine=`echo "$$restOfFile" \
	| grep -E -m 1 -n "^\[[[:alnum:]]+\][[:space:]]*$$" \
	| cut -d ':' -f 1`; \
if [ -n "$$nextSectionLine" ]; then \
	nextSectionLine=`expr $$nextSectionLine - 1`; \
	restOfFile=`echo "$$restOfFile" | head -n $$nextSectionLine`; \
fi; \
restOfFile=`echo "$$restOfFile" | grep -E -v "^[[:space:]]*;"`; \
echo "$$restOfFile" | grep -E "^[[:space:]]*$2[[:space:]]*=[[:space:]]*" \
| cut -d '=' -f 2- | sed -e 's/^ *//g' -e 's/ *$$//g')
#End of the function


EXENAME = $(call readConfig,names,exename)
SRCDIR = $(call readConfig,names,srcdir)
BUILDDIR = $(call readConfig,names,builddir)
BINDIR = $(BUILDDIR)$(call readConfig,names,bindir)
OBJDIR = $(BUILDDIR)$(call readConfig,names,objdir)
ASMDIR = $(BUILDDIR)$(call readConfig,names,asmdir)
PREDIR = $(BUILDDIR)$(call readConfig,names,predir)
DEPDIR = $(BUILDDIR)$(call readConfig,names,depdir)
EXE = $(BINDIR)$(EXENAME)

SYSHEADERDIR = $(call readConfig,preprocessing,headerdirs)
LIBDIR = $(call readConfig,linking,libdirs)
LIBSYS = $(call readConfig,linking,syslibs)

#--Available modes are C and CPP--#
MODE = $(call readConfig,modes,mode)

#-COMPILATION OPTIONS-#
#********************************************************#
RELEASE = $(call readConfig,modes,release)
DETAILEDCOMP = $(call readConfig,modes,detailedcomp)
#********************************************************#

#PREPROCESSING#
PRECMD = @g++ -E
PREFLAGSCOMMON = -DPROGNAME="$(EXENAME)" $(addprefix -I , $(SYSHEADERDIR))
PREFLAGSCOMMON += $(call readConfig,preprocessing,flagscommon)
PREFLAGSDEBUG = $(call readConfig,preprocessing,flagsdebug)
PREFLAGSRELEASE = $(call readConfig,preprocessing,flagsrelease)
PREFLAGS = $(PREFLAGSCOMMON)

#COMPILING#
COMPCMD = @g++ -S
COMPFLAGSCOMMON = $(call readConfig,compiling,flagscommon)
COMPFLAGSDEBUG = $(call readConfig,compiling,flagsdebug)
COMPFLAGSRELEASE = $(call readConfig,compiling,flagsrelease)
COMPFLAGS = $(COMPFLAGSCOMMON)

#ASSEMBLING#
ASMCMD = @g++ -c
ASMFLAGSCOMMON = $(call readConfig,assembling,flagscommon)
ASMFLAGSDEBUG = $(call readConfig,assembling,flagsdebug)
ASMFLAGSRELEASE = $(call readConfig,assembling,flagsrelease)
ASMFLAGS = $(ASMFLAGSCOMMON)

#LINKING#
LNKCMD = @g++
LNKFLAGSCOMMON = $(addprefix -L , $(LIBDIR))
LNKFLAGSCOMMON += $(call readConfig,linking,flagscommon)
LNKFLAGSDEBUG = $(call readConfig,linking,flagsdebug)
LNKFLAGSRELEASE = $(call readConfig,linking,flagsrelease)
LNKFLAGS = $(LNKFLAGSCOMMON)


EXTSTATICLIB = .a
EXTASM = .s
EXTOBJ = .o
EXTDEP = .d

EXTCPP = .cpp
EXTHPP = .hpp
EXTC = .c
EXTH = .h
EXTCPPPRE = .ii
EXTCPRE = .i

ifeq ($(MODE),C)
	EXTSRC = $(EXTC)
	EXTPRE = $(EXTCPRE)
endif

ifeq ($(MODE),CPP)
	EXTSRC = $(EXTCPP)
	EXTPRE = $(EXTCPPPRE)
endif


#--SOURCE CODE, PREPROCESSOR, ASSEMBLY, OBJECTS & DEPENDENCIES FILE NAMES--#
$(shell mkdir -p $(SRCDIR) $(LIBDIR))

HEADERS = $(shell find $(SRCDIR) -iname "*$(EXTH)")
ifeq ($(MODE),CPP)
	HEADERS += $(shell find $(SRCDIR) -iname "*$(EXTHPP)")
endif

SOURCES = $(shell find $(SRCDIR) -iname "*$(EXTSRC)" | sort)
PRE = $(addprefix $(PREDIR), $(notdir $(SOURCES:%$(EXTSRC)=%$(EXTPRE))))
ASM = $(addprefix $(ASMDIR), $(notdir $(SOURCES:%$(EXTSRC)=%$(EXTASM))))
OBJ = $(addprefix $(OBJDIR), $(notdir $(SOURCES:%$(EXTSRC)=%$(EXTOBJ))))
DEP = $(addprefix $(DEPDIR), $(notdir $(SOURCES:%$(EXTSRC)=%$(EXTDEP))))

LIBS = $(LIBSYS)
ifneq ($(words $(LIBDIR)),0)
	STATICLIBS = $(shell find $(LIBDIR) -maxdepth 1 -iname "*$(EXTSTATICLIB)")
	LIBAUTO = $(patsubst lib%,-l%, $(notdir $(basename $(STATICLIBS))))
	LIBS += $(LIBAUTO)
endif


#--RELEASE / DEBUG FLAGS CONFIGURATION--#
ifeq ($(RELEASE),yes)
	PREFLAGS += $(PREFLAGSRELEASE)
	COMPFLAGS += $(COMPFLAGSRELEASE)
	ASMFLAGS += $(ASMFLAGSRELEASE)
	LNKFLAGS += $(LNKFLAGSRELEASE)
else
	PREFLAGS += $(PREFLAGSDEBUG)
	COMPFLAGS += $(COMPFLAGSDEBUG)
	ASMFLAGS += $(ASMFLAGSDEBUG)
	LNKFLAGS += $(LNKFLAGSDEBUG)
endif

ifneq ($(DETAILEDCOMP),yes)
	ASMFLAGS += $(PREFLAGS) $(COMPFLAGS)
endif

PREC = $(strip $(PRECMD) $(PREFLAGS))
COMPC = $(strip $(COMPCMD) $(COMPFLAGS))
ASMC = $(strip $(ASMCMD) $(ASMFLAGS))
LNKC = $(strip $(LNKCMD) $(LNKFLAGS))


#--PHONY TARGET NAMES--#
CLEAN = clean
MRPROPER = mrproper
ALL = all
STATS = stats


#--CONFIGURE CLEAN & MRPROPER--#
CLEANFOLDERS = $(OBJDIR) $(ASMDIR) $(PREDIR) $(DEPDIR)
MRPROPERFOLDERS = $(BUILDDIR)


#--BASH COMMANDS--#
MKDIRCMD = @mkdir
MKDIRFLAGS = -p
MKDIR = $(MKDIRCMD) $(MKDIRFLAGS)

RMCMD = @rm
RMFLAGS = -rf
RM = $(RMCMD) $(RMFLAGS)

ECHOCMD = @echo
ECHOFLAGS =
ECHO = $(ECHOCMD) $(ECHOFLAGS)

PRINTFCMD = @printf
PRINTFFLAGS =
PRINTF = $(PRINTFCMD) $(PRINTFFLAGS)

WCCMD = @wc
WCFLAGS = -l
WC = $(WCCMD) $(WCFLAGS)

LNCMD = @ln
LNFLAGS = -fs
LN = $(LNCMD) $(LNFLAGS)

SORTCMD = sort
SORTFLAGS = -rn
SORT = $(SORTCMD) $(SORTFLAGS)


#--------SPECIAL RULES--------#
.PHONY: $(CLEAN) $(MRPROPER) $(ALL) $(STATS)
.PRECIOUS: $(PRE) $(ASM) $(OBJ) $(DEP)
.SECONDEXPANSION:


#--------RULES--------#
ifeq ($(words $(SOURCES)),0)
$(EXE):
	$(ECHO) "No source file has been found."
	$(ECHO) "Please check there is at least one « *$(EXTSRC) » file in the « $(SRCDIR) » folder."
else
$(EXE): $(OBJ) $(STATICLIBS)
	$(MKDIR) $(BINDIR)
	$(PRINTF) "%-13s <$@>...\n" "Linking"
	$(LNKC) -o $@ $(OBJ) $(LIBS)
	$(LN) $@ $(EXENAME)
endif

ifeq ($(DETAILEDCOMP),yes)
$(OBJDIR)%$(EXTOBJ): $(ASMDIR)%$(EXTASM)
	$(MKDIR) $(OBJDIR)
	$(PRINTF) "%-13s <$<>...\n" "Assembling"
	$(ASMC) -o $@ $<

$(ASMDIR)%$(EXTASM): $(PREDIR)%$(EXTPRE)
	$(MKDIR) $(ASMDIR)
	$(PRINTF) "%-13s <$<>...\n" "Compiling"
	$(COMPC) -o $@ $<

$(PREDIR)%$(EXTPRE): $$(shell find $(SRCDIR) -iname '%$(EXTSRC)') $(THIS)
	$(MKDIR) $(PREDIR)
	$(MKDIR) $(DEPDIR)
	$(PRINTF) "%-13s <$<>...\n" "Preprocessing"
	$(PREC) -o $@ -MMD -MT $@ -MF $(addprefix $(DEPDIR), $(notdir $(<:$(EXTSRC)=$(EXTDEP)))) $<
else
$(OBJDIR)%$(EXTOBJ): $$(shell find $(SRCDIR) -iname '%$(EXTSRC)') $(THIS)
	$(MKDIR) $(OBJDIR)
	$(MKDIR) $(DEPDIR)
	$(PRINTF) "%-13s <$<>...\n" "Compiling"
	$(ASMC) -o $@ -MMD -MF $(addprefix $(DEPDIR), $(notdir $(<:$(EXTSRC)=$(EXTDEP)))) $<
endif


#--------INCLUDE AUTOMATIC GENERATED DEPENDENCIES--------#
-include $(DEP)



#--------PHONY RULES--------#
$(ALL): $(MRPROPER) $(EXE)

$(MRPROPER):
	$(RM) $(EXENAME) $(MRPROPERFOLDERS)

$(CLEAN):
	$(RM) $(EXENAME) $(CLEANFOLDERS)

ifneq ($(words $(SOURCES)),0)
$(STATS):
	$(ECHO) "Stats of header files"
	$(WC) $(HEADERS) | $(SORT)
	$(ECHO)
	$(ECHO) "Stats of source files"
	$(WC) $(SOURCES) | $(SORT)
	$(ECHO)
	$(ECHO) "Total number of lines:" "$(shell cat $(HEADERS) $(SOURCES) | wc -l)"
else
$(STATS):
	$(ECHO) "There is no source file."
endif


#--------INCLUDE USER ADD-ON TO MAKEFILE (IF ANY)--------#
-include $(MAKEFILEADDONS)
