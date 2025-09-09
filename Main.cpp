#include "Common\Common.h"
#include "Common\SinTables.h"

#include "ThirdParty\CImg.h"
using namespace cimg_library;

#define NUM_FREQS_ON_SCREEN 40

static const int SineTableLength = 128;

struct OUT_SONG_DATA
{
	unsigned char SongName_Artist[40];
	unsigned char InitAddr[2];
	unsigned char PlayAddr[2];
	unsigned char VolumeAddr[2];
	unsigned char NumPlayCallsPerFrame;
};

struct SONG_SETUP
{
	wchar_t InSIDFilename[64];
	wchar_t OutBINFilename[64];
	char SongName[32];
	char ArtistName[32];
	unsigned short InitAddr;
	unsigned short PlayAddr;
	unsigned short VolumeAddr;
	int NumPlayCallsPerFrame;
} SongSetup[] =
{
	{
		L"6502\\Music\\Psych858o-NoBounds.sid",
		L"Out\\Built\\MusicData\\Psych858o-NoBounds.bin",
		"No Bounds",
		"Psych858o",
		0x0900,
		0x0903,
		0x07ff,
		1
	},

	{
		L"6502\\Music\\Flex-Hawkeye.sid",
		L"Out\\Built\\MusicData\\Flex-Hawkeye.bin",
		"Hawkeye",
		"Flex",
		0x0ff6,
		0x1003,
		0x07ff,
		2
	},

	{
		L"6502\\Music\\Nordischsound-MonkeyIslandLeChuck.sid",
		L"Out\\Built\\MusicData\\Nordischsound-MonkeyIslandLeChuck.bin",
		"Monkey Island LeChuck",
		"Nordischsound",
		0x1000,
		0x1003,
		0x07ff,
		1
	},

	

	{
		L"6502\\Music\\Psych858o-LastNightOnTheLonelyIsland.sid",
		L"Out\\Built\\MusicData\\Psych858o-LastNightOnTheLonelyIsland.bin",
		"Last Night",
		"Psych858o",
		0x2551,
		0x2564,
		0x07ff,
		6
	},

	{
		L"6502\\Music\\DJSpace-MontyIsAManiac.sid",
		L"Out\\Built\\MusicData\\DJSpace-MontyIsAManiac.bin",
		"Monty is a Maniac",
		"DJ Space",
		0x0ff6,
		0x1003,
		0x07ff,
		2
	},

	{
		L"6502\\Music\\Dane-SlowMotionSong.sid",
		L"Out\\Built\\MusicData\\Dane-SlowMotionSong.bin",
		"Slow Motion Song",
		"Dane",
		0x2400,
		0x1000,
		0x07ff,
		1
	},

	{
		L"6502\\Music\\Dane-CopperBooze.sid",
		L"Out\\Built\\MusicData\\Dane-CopperBooze.bin",
		"Copper Booze",
		"Dane",
		0x12f0,
		0x0800,
		0x07ff,
		1
	},

	{
		L"6502\\Music\\Toggle-Fireflies.sid",
		L"Out\\Built\\MusicData\\Toggle-Fireflies.bin",
		"Fireflies",
		"Toggle",
		0x1000,
		0x1003,
		0x07ff,
		1
	},

	{
		L"6502\\Music\\Laxity-LastNightOf89.sid",
		L"Out\\Built\\MusicData\\Laxity-LastNightOf89.bin",
		"Last Night of 89",
		"Laxity",
		0x1000,
		0x1006,
		0x07ff,
		1
	},

	{
		L"6502\\Music\\Psych858o-SabreWulfPrev.sid",
		L"Out\\Built\\MusicData\\Psych858o-SabreWulfPrev.bin",
		"Sabre Wulf Remastered Prv",
		"Psych858o",
		0x1000,
		0x1003,
		0x07ff,
		1
	},

	{
		L"6502\\Music\\Magnar-MagnumPI.sid",
		L"Out\\Built\\MusicData\\Magnar-MagnumPI.bin",
		"Magnum PI Theme",
		"Magnar",
		0x1000,
		0x1003,
		0x07ff,
		1
	},

	{
		L"6502\\Music\\Psych858o-CrockettsTheme.sid",
		L"Out\\Built\\MusicData\\Psych858o-CrockettsTheme.bin",
		"Crockett's Theme",
		"Psych858o",
		0x1000,
		0x1003,
		0x07ff,
		1
	},

	{
		L"6502\\Music\\Magnar-OldSkool.sid",
		L"Out\\Built\\MusicData\\Magnar-OldSkool.bin",
		"Airwolf",
		"Magnar",
		0x1000,
		0x1003,
		0x07ff,
		1
	},

	{
		L"6502\\Music\\Psych858o-OnTheWaves.sid",
		L"Out\\Built\\MusicData\\Psych858o-OnTheWaves.bin",
		"On The Waves",
		"Psych858o",
		0x1000,
		0x1003,
		0x07ff,
		1
	},

	{
		L"6502\\Music\\Jammer-TakeYourTimeBabe-6x.sid",
		L"Out\\Built\\MusicData\\Jammer-TakeYourTimeBabe-6x.bin",
		"Take Your Time Babe",
		"Jammer",
		0x0ff6,
		0x1003,
		0x07ff,
		6
	},

	{
		L"6502\\Music\\PartyPiratesSide1.sid",
		L"Out\\Built\\MusicData\\PartyPiratesSide1.bin",
		"Party Pirates 1",
		"Stinsen and Steel",
		0x1000,
		0x1003,
		0x07ff,
		1
	},

	{
		L"6502\\Music\\Zardax-NoConocida.sid",
		L"Out\\Built\\MusicData\\Zardax-NoConocida.bin",
		"No Conocida",
		"Zardax",
		0x1000,
		0x1003,
		0x07ff,
		1
	},

	{
		L"6502\\Music\\Drax-ExpandSide2.sid",
		L"Out\\Built\\MusicData\\Drax-ExpandSide2.bin",
		"Expand Side 2",
		"Drax",
		0x1000,
		0x1003,
		0x07ff,
		1
	},

	{
		L"6502\\Music\\Flex-Lundia.sid",
		L"Out\\Built\\MusicData\\Flex-Lundai.bin",
		"Lundia",
		"Flex",
		0x0ff6,
		0x1003,
		0x07ff,
		2
	},

	{
		L"6502\\Music\\Jangler-Dynamite-2x.sid",
		L"Out\\Built\\MusicData\\Jangler-Dynamite-2x.bin",
		"Dynamite",
		"Jangler",
		0x0ff6,
		0x1003,
		0x07ff,
		2
	},

	{
		L"6502\\Music\\PartyPiratesSide2.sid",
		L"Out\\Built\\MusicData\\PartyPiratesSide2.bin",
		"Party Pirates 2",
		"Stinsen and Steel",
		0x1000,
		0x1003,
		0x07ff,
		1
	},

	{
		L"6502\\Music\\Stinsen-Arpalooza.sid",
		L"Out\\Built\\MusicData\\Stinsen-Arpalooza.bin",
		"Arpalooza",
		"Stinsen",
		0x1000,
		0x1003,
		0x07ff,
		1
	},

	{
		L"6502\\Music\\Linus-Commando.sid",
		L"Out\\Built\\MusicData\\Linus-Commando.bin",
		"Commando",
		"Linus",
		0x1000,
		0x1003,
		0x07ff,
		1
	},

	{
		L"6502\\Music\\Linus-Monty.sid",
		L"Out\\Built\\MusicData\\Linus-Monty.bin",
		"Monty",
		"Linus",
		0x0800,
		0x0803,
		0x07ff,
		1
	},

	{
		L"6502\\Music\\Flex-Lundia-2x.sid",
		L"Out\\Built\\MusicData\\Flex-Lundia-2x.bin",
		"Lundia",
		"Flex",
		0x0ff6,
		0x1003,
		0x07ff,
		2
	},

	{
		L"6502\\Music\\Zardax-NoConocida-2x.sid",
		L"Out\\Built\\MusicData\\Zardax-NoConocida-2x.bin",
		"No Conocida",
		"Zardax",
		0x1000,
		0x1003,
		0x07ff,
		2
	},

	{
		L"6502\\Music\\Jangler-Dynamite-2x.sid",
		L"Out\\Built\\MusicData\\Jangler-Dynamite-2x.bin",
		"Dynamite",
		"Jangler",
		0x0ff6,
		0x1003,
		0x07ff,
		2
	},

	{
		L"6502\\Music\\Fegolhuzz-AntikrundanAllstars.sid",
		L"Out\\Built\\MusicData\\Fegolhuzz-AntikrundanAllstars.bin",
		"Antikrundan Allstars",
		"Fegolhuzz",
		0x1000,
		0x1003,
		0x07ff,
		1
	},

	{
		L"6502\\Music\\Steel-TheCIsMine.sid",
		L"Out\\Built\\MusicData\\Steel-TheCIsMine.bin",
		"The C Is Mine",
		"Steel",
		0x1000,
		0x1003,
		0x07ff,
		1
	},

	{
		L"6502\\Music\\DangerDawg.sid",
		L"Out\\Built\\MusicData\\DangerDawg.bin",
		"Danger Dawg",
		"MCH",
		0x1000,
		0x1003,
		0x07ff,
		1
	},

	{
		L"6502\\Music\\demo-mch.sid",
		L"Out\\Built\\MusicData\\demo-mch.bin",
		"Delirious 11",
		"MCH",
		0x1000,
		0x1003,
		0x07ff,
		1
	},

	{
		L"6502\\Music\\Magnar-Wonderland12.sid",
		L"Out\\Built\\MusicData\\Magnar-Wonderland12.bin",
		"Wonderland 12",
		"Magnar",
		0x1000,
		0x1003,
		0x07ff,
		1
	},

	{
		L"6502\\Music\\Stinsen-Alla.sid",
		L"Out\\Built\\MusicData\\Stinsen-Alla.bin",
		"Alla",
		"Stinsen",
		0x1000,
		0x1003,
		0x07ff,
		1
	},

	{
		L"6502\\Music\\MCH-GirlInTown.sid",
		L"Out\\Built\\MusicData\\MCH-GirlInTown.bin",
		"Girl In Town",
		"MCH",
		0x1000,
		0x1003,
		0x07ff,
		1
	},

	{
		L"6502\\Music\\Dive.sid",
		L"Out\\Built\\MusicData\\Dive.bin",
		"The Dive",
		"MCH",
		0x1000,
		0x1003,
		0x07ff,
		1
	},

	{
		L"6502\\Music\\Deek-Endtune.sid",
		L"Out\\Built\\MusicData\\Deek-Endtune.bin",
		"The Dive End Tune",
		"Deek",
		0x1000,
		0x1003,
		0x07ff,
		1
	},

	{
		L"6502\\Music\\Drax-FadeIn.sid",
		L"Out\\Built\\MusicData\\Drax-FadeIn.bin",
		"Fade In",
		"Drax",
		0x1000,
		0x1003,
		0x07ff,
		1
	},

	{
		L"6502\\Music\\MarioIsDead.sid",
		L"Out\\Built\\MusicData\\MarioIsDead.bin",
		"Mario is Dead",
		"MCH and Jammer",
		0x1000,
		0x1003,
		0x07ff,
		1
	},

	{
		L"6502\\Music\\Fegolhuzz-AntikrundanAllstars.sid",
		L"Out\\Built\\MusicData\\Fegolhuzz-AntikrundanAllstars.bin",
		"Antikrundan Allstars",
		"Fegolhuzz",
		0x1000,
		0x1003,
		0x07ff,
		1
	},

	{
		L"6502\\Music\\MrDeath-Bongo.sid",
		L"Out\\Built\\MusicData\\MrDeath-Bongo.bin",
		"Bongo",
		"Mr Death",
		0x1000,
		0x1003,
		0x07ff,
		1
	},

	{
		L"6502\\Music\\.sid",
		L"Out\\Built\\MusicData\\.bin",
		"",
		"",
		0x1000,
		0x1003,
		0x07ff,
		1
	},

	{
		L"6502\\Music\\Stinsen-BaitAndSwitch.sid",
		L"Out\\Built\\MusicData\\Stinsen-BaitAndSwitch.bin",
		"Bait and Switch",
		"Stinsen",
		0x1000,
		0x1003,
		0x07ff,
		1
	},

/*{
		L"6502\\Music\\.sid",
		L"Out\\Built\\MusicData\\.bin",
		"",
		"",
		0x1000,
		0x1003,
		0x07ff,
		1
	},

	{
		L"6502\\Music\\.sid",
		L"Out\\Built\\MusicData\\.bin",
		"",
		"",
		0x1000,
		0x1003,
		0x07ff,
		1
	},*/

};
static const int NumSongs = sizeof(SongSetup) / sizeof(SONG_SETUP);

unsigned char RemapChar(unsigned char InChar)
{
	unsigned char OutChar = 0;

	if ((InChar >= 'A') && (InChar <= 'Z'))
		OutChar = 0x40 + (InChar & 0x1f);
	else if ((InChar >= 'a') && (InChar <= 'z'))
		OutChar = 0x00 + (InChar & 0x1f);
	else
	{
		OutChar = InChar & 0x7f;
		if (OutChar >= 0x60)
			OutChar = 0x20;
	}

	return OutChar;
}

int AddCharToSongLine(OUT_SONG_DATA& OutSongData, int OutIndex, unsigned char OutChar)
{
	if ((OutIndex >= 0) && (OutIndex < 40))
	{
		OutSongData.SongName_Artist[OutIndex] = OutChar;
	}
	OutIndex++;
	return OutIndex;
}



void OutputSongData(void)
{
	OUT_SONG_DATA OutSongData;
	for (int Index = 0; Index < NumSongs; Index++)
	{
		SONG_SETUP& rSong = SongSetup[Index];

		ZeroMemory(&OutSongData, sizeof(OUT_SONG_DATA));

		OutSongData.InitAddr[0] = (rSong.InitAddr % 256);
		OutSongData.InitAddr[1] = (rSong.InitAddr / 256);

		OutSongData.PlayAddr[0] = (rSong.PlayAddr % 256);
		OutSongData.PlayAddr[1] = (rSong.PlayAddr / 256);

		OutSongData.VolumeAddr[0] = (rSong.VolumeAddr % 256);
		OutSongData.VolumeAddr[1] = (rSong.VolumeAddr / 256);

		OutSongData.NumPlayCallsPerFrame = rSong.NumPlayCallsPerFrame;

		memset(OutSongData.SongName_Artist, 0x20, sizeof(OutSongData.SongName_Artist));

		int nameStringLen =  static_cast<int>(strlen(rSong.SongName));
		int artistStringLen = static_cast<int>(strlen(rSong.ArtistName));
		int stringLen = 1 + nameStringLen + 5 + artistStringLen;

		int OutIndex = (40 - stringLen) / 2;

		OutIndex = AddCharToSongLine(OutSongData, OutIndex, '\"');
		for (int i = 0; i < nameStringLen; i++)
		{
			char InChar = rSong.SongName[i];
			if (InChar == 0)
			{
				break;
			}
			OutIndex = AddCharToSongLine(OutSongData, OutIndex, RemapChar(InChar));
		}
		OutIndex = AddCharToSongLine(OutSongData, OutIndex, '\"');
		OutIndex = AddCharToSongLine(OutSongData, OutIndex, ' ');
		OutIndex = AddCharToSongLine(OutSongData, OutIndex, RemapChar('b'));
		OutIndex = AddCharToSongLine(OutSongData, OutIndex, RemapChar('y'));
		OutIndex = AddCharToSongLine(OutSongData, OutIndex, ' ');

		for (int i = 0; i < artistStringLen; i++)
		{
			char InChar = rSong.ArtistName[i];
			if (InChar == 0)
			{
				break;
			}
			OutIndex = AddCharToSongLine(OutSongData, OutIndex, RemapChar(InChar));
		}

		WriteBinaryFile(rSong.OutBINFilename, &OutSongData, sizeof(OUT_SONG_DATA));
	}
}



void GenerateFreqLookups(LPCTSTR FreqBINFilename)
{
	unsigned short NewFreqTable[NUM_FREQS_ON_SCREEN];

	// Generate logarithmic thresholds (your new code)
	const unsigned short MIN_FREQ = 0x0080;
	const unsigned short MAX_FREQ = 0xFFFF;

	for (int FreqIndex = 0; FreqIndex < NUM_FREQS_ON_SCREEN; FreqIndex++)
	{
		double factor = pow((double)MAX_FREQ / MIN_FREQ,
			(double)(FreqIndex + 0.5) / NUM_FREQS_ON_SCREEN);
		NewFreqTable[FreqIndex] = (unsigned short)(MIN_FREQ * factor + 0.5);
	}

	unsigned char OutFreqTable[2][256];

	for (int Index = 0; Index < 256; Index++)
	{
		// For high byte method: when freq high byte >= 16, we use this directly
		// We want smooth mapping from frequencies 0x1000 to 0xFFFF
		unsigned short FreqHiTest = Index * 256 + 128;

		// For low byte method: for frequencies < 0x1000
		// This needs to map the range 0x0000 to 0x0FFF properly
		unsigned short FreqLoTest;
		if (Index < 64) {
			// For very low frequencies (high byte would be 0)
			FreqLoTest = Index * 4;
		}
		else {
			// For mid frequencies (high byte would be 1-15)
			// Scale to cover range 0x100 to 0xFFF
			FreqLoTest = 0x100 + ((Index - 64) * 0xF00 / 192);
		}

		unsigned char FreqHiVal = 0;
		unsigned char FreqLoVal = 0;

		// Count how many thresholds are below each test value
		for (int FreqIndex = 0; FreqIndex < NUM_FREQS_ON_SCREEN; FreqIndex++)
		{
			if (NewFreqTable[FreqIndex] < FreqHiTest)
			{
				FreqHiVal++;
			}
			if (NewFreqTable[FreqIndex] < FreqLoTest)
			{
				FreqLoVal++;
			}
		}

		OutFreqTable[0][Index] = FreqHiVal;
		OutFreqTable[1][Index] = FreqLoVal;
	}

	WriteBinaryFile(FreqBINFilename, OutFreqTable, sizeof(OutFreqTable));
}

void GenerateFreqLookups2(LPCTSTR FreqBINFilename)
{
	// Generate 40 logarithmic thresholds
	unsigned short BarThresholds[NUM_FREQS_ON_SCREEN + 1];
	const unsigned short MIN_FREQ = 0x0080;
	const unsigned short MAX_FREQ = 0xFFFF;

	BarThresholds[0] = 0;
	for (int FreqIndex = 0; FreqIndex < NUM_FREQS_ON_SCREEN; FreqIndex++)
	{
		double factor = pow((double)MAX_FREQ / MIN_FREQ,
			(double)(FreqIndex + 1) / NUM_FREQS_ON_SCREEN);
		BarThresholds[FreqIndex + 1] = (unsigned short)(MIN_FREQ * factor + 0.5);
	}

	// Create three tables for different frequency ranges
	unsigned char FreqToBarLo[256];   // For freq < 0x1000 (high byte 0-15)
	unsigned char FreqToBarMid[256];  // For freq 0x1000-0x3FFF (high byte 16-63)  
	unsigned char FreqToBarHi[256];   // For freq >= 0x4000 (high byte 64-255)

	// Low frequency table - use more precision
	for (int Index = 0; Index < 256; Index++)
	{
		// Map 0-255 to frequencies 0x0000-0x0FFF
		unsigned short FreqMid = (Index << 4) + 8;  // Index * 16 + midpoint

		unsigned char BarIndex = 0;
		for (int Bar = 0; Bar < NUM_FREQS_ON_SCREEN; Bar++)
		{
			if (FreqMid >= BarThresholds[Bar] &&
				FreqMid < BarThresholds[Bar + 1])
			{
				BarIndex = Bar;
				break;
			}
		}
		FreqToBarLo[Index] = BarIndex;
	}

	// Mid frequency table
	for (int Index = 0; Index < 256; Index++)
	{
		// Map 0-255 to frequencies 0x1000-0x3FFF
		unsigned short FreqMid = 0x1000 + (Index << 5) + 16;  // 0x1000 + Index * 32

		unsigned char BarIndex = 0;
		for (int Bar = 0; Bar < NUM_FREQS_ON_SCREEN; Bar++)
		{
			if (FreqMid >= BarThresholds[Bar] &&
				FreqMid < BarThresholds[Bar + 1])
			{
				BarIndex = Bar;
				break;
			}
		}
		FreqToBarMid[Index] = BarIndex;
	}

	// High frequency table - direct high byte mapping
	for (int Index = 0; Index < 256; Index++)
	{
		unsigned short FreqMid = (Index << 8) + 128;

		unsigned char BarIndex = 0;
		for (int Bar = 0; Bar < NUM_FREQS_ON_SCREEN; Bar++)
		{
			if (FreqMid >= BarThresholds[Bar] &&
				FreqMid < BarThresholds[Bar + 1])
			{
				BarIndex = Bar;
				break;
			}
		}
		if (FreqMid >= BarThresholds[NUM_FREQS_ON_SCREEN])
		{
			BarIndex = NUM_FREQS_ON_SCREEN - 1;
		}
		FreqToBarHi[Index] = BarIndex;
	}

	// Write all three tables (768 bytes total)
	unsigned char AllTables[768];
	memcpy(AllTables, FreqToBarLo, 256);
	memcpy(AllTables + 256, FreqToBarMid, 256);
	memcpy(AllTables + 512, FreqToBarHi, 256);
	WriteBinaryFile(FreqBINFilename, AllTables, sizeof(AllTables));
}

void GenerateSoundSineBar(LPCTSTR SoundSineBarBINFilename)
{
	unsigned char SinTable[SineTableLength];
	for (int Index = 0; Index < SineTableLength; Index++)
	{
		double Angle = (Index * (PI / 2.0)) / SineTableLength;
		double SineVal = sin(Angle) * 79;
		SinTable[Index] = (unsigned char)SineVal;
	}

	WriteBinaryFile(SoundSineBarBINFilename, SinTable, SineTableLength);
}

void GenerateSpriteSineBar(LPCTSTR SpriteSineBarBINFilename)
{
	unsigned char SinTable[2][128];
	for (int Index = 0; Index < 128; Index++)
	{
		double Angle0 = (Index * 2 * PI) / 128;
		double SineVal = sin(Angle0) * 27.5 + 27.5;
		int iSineVal = (int)SineVal;
		int XPos = iSineVal;
		SinTable[0][Index] = (unsigned char)(iSineVal % 256);

		unsigned char XMSB = 0;
		for (int SpriteIndex = 0; SpriteIndex < 7; SpriteIndex++)
		{
			if ((XPos >= 256) || (XPos < 0))
			{
				XMSB |= (1 << SpriteIndex);
			}
			XPos += 48;
		}
		SinTable[1][Index] = XMSB;
	}

	WriteBinaryFile(SpriteSineBarBINFilename, SinTable, sizeof(SinTable));
}

void UpdateBarChars(unsigned char* BarChars)
{
	for (int c = 0; c < 10; c++)
	{
		int TopPos = 8 - c;
		if ((TopPos & 3) == 1)
			TopPos++;

		for (int y = 0; y < 8; y++)
		{
			unsigned char OutChar = 0;
			unsigned char ReflectionOutChar0 = 0;
			unsigned char ReflectionOutChar1 = 0;

			if (y == TopPos)
			{
				OutChar = 0x7c;
			}
			else if (y > TopPos)
			{
				OutChar = 0xbe;
			}

			if (OutChar != 0)
			{
				ReflectionOutChar0 = (((y + c) & 1) == 0) ? 0x54 : 0xaa;
				ReflectionOutChar1 = (((y + c) & 1) == 1) ? 0x54 : 0xaa;
			}

			if ((y & 3) == 1)
				OutChar = 0;

			int OutIndex = ((c + 0) * 8) + y;
			BarChars[OutIndex] = OutChar;

			int ReflectionOutIndex0 = ((c + 10) * 8) + (7 - y);
			int ReflectionOutIndex1 = ((c + 20) * 8) + (7 - y);
			BarChars[ReflectionOutIndex0] = ReflectionOutChar0;
			BarChars[ReflectionOutIndex1] = ReflectionOutChar1;
		}
	}
}


void MergeCharSets(LPCTSTR InCharSetMAPFilename, LPCTSTR OutCharSetMAPFilename)
{
	unsigned char CharSet[256 * 8];

	ReadBinaryFile(InCharSetMAPFilename, CharSet, sizeof(CharSet));

	UpdateBarChars(&CharSet[224 * 8]);

	WriteBinaryFile(OutCharSetMAPFilename, CharSet, sizeof(CharSet));
}

int main()
{
	_mkdir("Out");
	_mkdir("Out\\Built");
	_mkdir("Out\\Built\\MusicData");

	GenerateFreqLookups(L"Out\\Built\\FreqTable.bin");

	GenerateFreqLookups2(L"Out\\Built\\FreqTable2.bin");

	GenerateSoundSineBar(L"Out\\Built\\SoundbarSine.bin");

	GenerateSpriteSineBar(L"Out\\Built\\SpriteSine.bin");

	OutputSongData();

	MergeCharSets(L"SourceData\\scrap-1x2font.map", L"Out\\Built\\CharSet.map");
}
